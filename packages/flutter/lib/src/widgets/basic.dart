import 'dart:math' as math;
import 'dart:ui' as ui show Image, ImageFilter, TextHeightBehavior;

import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'binding.dart';
import 'debug.dart';
import 'framework.dart';
import 'localizations.dart';
import 'visibility.dart';
import 'widget_span.dart';

export 'package:flutter/animation.dart';
export 'package:flutter/foundation.dart'
    show
        ChangeNotifier,
        FlutterErrorDetails,
        Listenable,
        TargetPlatform,
        ValueNotifier;
export 'package:flutter/painting.dart';
export 'package:flutter/rendering.dart'
    show
        AlignmentGeometryTween,
        AlignmentTween,
        Axis,
        BoxConstraints,
        BoxConstraintsTransform,
        CrossAxisAlignment,
        CustomClipper,
        CustomPainter,
        CustomPainterSemantics,
        DecorationPosition,
        FlexFit,
        FlowDelegate,
        FlowPaintingContext,
        FractionalOffsetTween,
        HitTestBehavior,
        LayerLink,
        MainAxisAlignment,
        MainAxisSize,
        MouseCursor,
        MultiChildLayoutDelegate,
        PaintingContext,
        PointerCancelEvent,
        PointerCancelEventListener,
        PointerDownEvent,
        PointerDownEventListener,
        PointerEvent,
        PointerMoveEvent,
        PointerMoveEventListener,
        PointerUpEvent,
        PointerUpEventListener,
        RelativeRect,
        SemanticsBuilderCallback,
        ShaderCallback,
        ShapeBorderClipper,
        SingleChildLayoutDelegate,
        StackFit,
        SystemMouseCursors,
        TextOverflow,
        ValueChanged,
        ValueGetter,
        WrapAlignment,
        WrapCrossAlignment;
export 'package:flutter/services.dart' show AssetBundle;

// Examples can assume:
// class TestWidget extends StatelessWidget { const TestWidget({super.key}); @override Widget build(BuildContext context) => const Placeholder(); }
// late WidgetTester tester;
// late bool _visible;
// class Sky extends CustomPainter { @override void paint(Canvas c, Size s) {} @override bool shouldRepaint(Sky s) => false; }
// late BuildContext context;
// String userAvatarUrl = '';

// BIDIRECTIONAL TEXT SUPPORT

class _UbiquitousInheritedElement extends InheritedElement {
  _UbiquitousInheritedElement(super.widget);

  @override
  void setDependencies(Element dependent, Object? value) {
    // This is where the cost of [InheritedElement] is incurred during build
    // time of the widget tree. Omitting this bookkeeping is where the
    // performance savings come from.
    assert(value == null);
  }

  @override
  Object? getDependencies(Element dependent) {
    return null;
  }

  @override
  void notifyClients(InheritedWidget oldWidget) {
    _recurseChildren(this, (Element element) {
      if (element.doesDependOnInheritedElement(this)) {
        notifyDependent(oldWidget, element);
      }
    });
  }

  static void _recurseChildren(Element element, ElementVisitor visitor) {
    element.visitChildren((Element child) {
      _recurseChildren(child, visitor);
    });
    visitor(element);
  }
}

abstract class _UbiquitousInheritedWidget extends InheritedWidget {
  const _UbiquitousInheritedWidget({super.key, required super.child});

  @override
  InheritedElement createElement() => _UbiquitousInheritedElement(this);
}

class Directionality extends _UbiquitousInheritedWidget {
  const Directionality({
    super.key,
    required this.textDirection,
    required super.child,
  });

  final TextDirection textDirection;

  static TextDirection of(BuildContext context) {
    assert(debugCheckHasDirectionality(context));
    final Directionality widget =
        context.dependOnInheritedWidgetOfExactType<Directionality>()!;
    return widget.textDirection;
  }

  static TextDirection? maybeOf(BuildContext context) {
    final Directionality? widget =
        context.dependOnInheritedWidgetOfExactType<Directionality>();
    return widget?.textDirection;
  }

  @override
  bool updateShouldNotify(Directionality oldWidget) =>
      textDirection != oldWidget.textDirection;

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(EnumProperty<TextDirection>('textDirection', textDirection));
  }
}

// PAINTING NODES

class Opacity extends SingleChildRenderObjectWidget {
  const Opacity({
    super.key,
    required this.opacity,
    this.alwaysIncludeSemantics = false,
    super.child,
  }) : assert(opacity >= 0.0 && opacity <= 1.0);

  final double opacity;

  final bool alwaysIncludeSemantics;

  @override
  RenderOpacity createRenderObject(BuildContext context) {
    return RenderOpacity(
      opacity: opacity,
      alwaysIncludeSemantics: alwaysIncludeSemantics,
    );
  }

  @override
  void updateRenderObject(BuildContext context, RenderOpacity renderObject) {
    renderObject
      ..opacity = opacity
      ..alwaysIncludeSemantics = alwaysIncludeSemantics;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DoubleProperty('opacity', opacity));
    properties.add(FlagProperty('alwaysIncludeSemantics',
        value: alwaysIncludeSemantics, ifTrue: 'alwaysIncludeSemantics'));
  }
}

class ShaderMask extends SingleChildRenderObjectWidget {
  const ShaderMask({
    super.key,
    required this.shaderCallback,
    this.blendMode = BlendMode.modulate,
    super.child,
  });

  final ShaderCallback shaderCallback;

  final BlendMode blendMode;

  @override
  RenderShaderMask createRenderObject(BuildContext context) {
    return RenderShaderMask(
      shaderCallback: shaderCallback,
      blendMode: blendMode,
    );
  }

  @override
  void updateRenderObject(BuildContext context, RenderShaderMask renderObject) {
    renderObject
      ..shaderCallback = shaderCallback
      ..blendMode = blendMode;
  }
}

class BackdropFilter extends SingleChildRenderObjectWidget {
  const BackdropFilter({
    super.key,
    required this.filter,
    super.child,
    this.blendMode = BlendMode.srcOver,
  });

  final ui.ImageFilter filter;

  final BlendMode blendMode;

  @override
  RenderBackdropFilter createRenderObject(BuildContext context) {
    return RenderBackdropFilter(filter: filter, blendMode: blendMode);
  }

  @override
  void updateRenderObject(
      BuildContext context, RenderBackdropFilter renderObject) {
    renderObject
      ..filter = filter
      ..blendMode = blendMode;
  }
}

class CustomPaint extends SingleChildRenderObjectWidget {
  const CustomPaint({
    super.key,
    this.painter,
    this.foregroundPainter,
    this.size = Size.zero,
    this.isComplex = false,
    this.willChange = false,
    super.child,
  }) : assert(painter != null ||
            foregroundPainter != null ||
            (!isComplex && !willChange));

  final CustomPainter? painter;

  final CustomPainter? foregroundPainter;

  final Size size;

  final bool isComplex;

  final bool willChange;

  @override
  RenderCustomPaint createRenderObject(BuildContext context) {
    return RenderCustomPaint(
      painter: painter,
      foregroundPainter: foregroundPainter,
      preferredSize: size,
      isComplex: isComplex,
      willChange: willChange,
    );
  }

  @override
  void updateRenderObject(
      BuildContext context, RenderCustomPaint renderObject) {
    renderObject
      ..painter = painter
      ..foregroundPainter = foregroundPainter
      ..preferredSize = size
      ..isComplex = isComplex
      ..willChange = willChange;
  }

  @override
  void didUnmountRenderObject(RenderCustomPaint renderObject) {
    renderObject
      ..painter = null
      ..foregroundPainter = null;
  }
}

class ClipRect extends SingleChildRenderObjectWidget {
  const ClipRect({
    super.key,
    this.clipper,
    this.clipBehavior = Clip.hardEdge,
    super.child,
  });

  final CustomClipper<Rect>? clipper;

  final Clip clipBehavior;

  @override
  RenderClipRect createRenderObject(BuildContext context) {
    return RenderClipRect(clipper: clipper, clipBehavior: clipBehavior);
  }

  @override
  void updateRenderObject(BuildContext context, RenderClipRect renderObject) {
    renderObject
      ..clipper = clipper
      ..clipBehavior = clipBehavior;
  }

  @override
  void didUnmountRenderObject(RenderClipRect renderObject) {
    renderObject.clipper = null;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<CustomClipper<Rect>>('clipper', clipper,
        defaultValue: null));
  }
}

class ClipRRect extends SingleChildRenderObjectWidget {
  const ClipRRect({
    super.key,
    this.borderRadius = BorderRadius.zero,
    this.clipper,
    this.clipBehavior = Clip.antiAlias,
    super.child,
  });

  final BorderRadiusGeometry borderRadius;

  final CustomClipper<RRect>? clipper;

  final Clip clipBehavior;

  @override
  RenderClipRRect createRenderObject(BuildContext context) {
    return RenderClipRRect(
      borderRadius: borderRadius,
      clipper: clipper,
      clipBehavior: clipBehavior,
      textDirection: Directionality.maybeOf(context),
    );
  }

  @override
  void updateRenderObject(BuildContext context, RenderClipRRect renderObject) {
    renderObject
      ..borderRadius = borderRadius
      ..clipBehavior = clipBehavior
      ..clipper = clipper
      ..textDirection = Directionality.maybeOf(context);
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<BorderRadiusGeometry>(
        'borderRadius', borderRadius,
        showName: false, defaultValue: null));
    properties.add(DiagnosticsProperty<CustomClipper<RRect>>('clipper', clipper,
        defaultValue: null));
  }
}

class ClipOval extends SingleChildRenderObjectWidget {
  const ClipOval({
    super.key,
    this.clipper,
    this.clipBehavior = Clip.antiAlias,
    super.child,
  });

  final CustomClipper<Rect>? clipper;

  final Clip clipBehavior;

  @override
  RenderClipOval createRenderObject(BuildContext context) {
    return RenderClipOval(clipper: clipper, clipBehavior: clipBehavior);
  }

  @override
  void updateRenderObject(BuildContext context, RenderClipOval renderObject) {
    renderObject
      ..clipper = clipper
      ..clipBehavior = clipBehavior;
  }

  @override
  void didUnmountRenderObject(RenderClipOval renderObject) {
    renderObject.clipper = null;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<CustomClipper<Rect>>('clipper', clipper,
        defaultValue: null));
  }
}

class ClipPath extends SingleChildRenderObjectWidget {
  const ClipPath({
    super.key,
    this.clipper,
    this.clipBehavior = Clip.antiAlias,
    super.child,
  });

  static Widget shape({
    Key? key,
    required ShapeBorder shape,
    Clip clipBehavior = Clip.antiAlias,
    Widget? child,
  }) {
    return Builder(
      key: key,
      builder: (BuildContext context) {
        return ClipPath(
          clipper: ShapeBorderClipper(
            shape: shape,
            textDirection: Directionality.maybeOf(context),
          ),
          clipBehavior: clipBehavior,
          child: child,
        );
      },
    );
  }

  final CustomClipper<Path>? clipper;

  final Clip clipBehavior;

  @override
  RenderClipPath createRenderObject(BuildContext context) {
    return RenderClipPath(clipper: clipper, clipBehavior: clipBehavior);
  }

  @override
  void updateRenderObject(BuildContext context, RenderClipPath renderObject) {
    renderObject
      ..clipper = clipper
      ..clipBehavior = clipBehavior;
  }

  @override
  void didUnmountRenderObject(RenderClipPath renderObject) {
    renderObject.clipper = null;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<CustomClipper<Path>>('clipper', clipper,
        defaultValue: null));
  }
}

class PhysicalModel extends SingleChildRenderObjectWidget {
  const PhysicalModel({
    super.key,
    this.shape = BoxShape.rectangle,
    this.clipBehavior = Clip.none,
    this.borderRadius,
    this.elevation = 0.0,
    required this.color,
    this.shadowColor = const Color(0xFF000000),
    super.child,
  }) : assert(elevation >= 0.0);

  final BoxShape shape;

  final Clip clipBehavior;

  final BorderRadius? borderRadius;

  final double elevation;

  final Color color;

  final Color shadowColor;

  @override
  RenderPhysicalModel createRenderObject(BuildContext context) {
    return RenderPhysicalModel(
      shape: shape,
      clipBehavior: clipBehavior,
      borderRadius: borderRadius,
      elevation: elevation,
      color: color,
      shadowColor: shadowColor,
    );
  }

  @override
  void updateRenderObject(
      BuildContext context, RenderPhysicalModel renderObject) {
    renderObject
      ..shape = shape
      ..clipBehavior = clipBehavior
      ..borderRadius = borderRadius
      ..elevation = elevation
      ..color = color
      ..shadowColor = shadowColor;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(EnumProperty<BoxShape>('shape', shape));
    properties
        .add(DiagnosticsProperty<BorderRadius>('borderRadius', borderRadius));
    properties.add(DoubleProperty('elevation', elevation));
    properties.add(ColorProperty('color', color));
    properties.add(ColorProperty('shadowColor', shadowColor));
  }
}

class PhysicalShape extends SingleChildRenderObjectWidget {
  const PhysicalShape({
    super.key,
    required this.clipper,
    this.clipBehavior = Clip.none,
    this.elevation = 0.0,
    required this.color,
    this.shadowColor = const Color(0xFF000000),
    super.child,
  }) : assert(elevation >= 0.0);

  final CustomClipper<Path> clipper;

  final Clip clipBehavior;

  final double elevation;

  final Color color;

  final Color shadowColor;

  @override
  RenderPhysicalShape createRenderObject(BuildContext context) {
    return RenderPhysicalShape(
      clipper: clipper,
      clipBehavior: clipBehavior,
      elevation: elevation,
      color: color,
      shadowColor: shadowColor,
    );
  }

  @override
  void updateRenderObject(
      BuildContext context, RenderPhysicalShape renderObject) {
    renderObject
      ..clipper = clipper
      ..clipBehavior = clipBehavior
      ..elevation = elevation
      ..color = color
      ..shadowColor = shadowColor;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
        .add(DiagnosticsProperty<CustomClipper<Path>>('clipper', clipper));
    properties.add(DoubleProperty('elevation', elevation));
    properties.add(ColorProperty('color', color));
    properties.add(ColorProperty('shadowColor', shadowColor));
  }
}

// POSITIONING AND SIZING NODES

class Transform extends SingleChildRenderObjectWidget {
  const Transform({
    super.key,
    required this.transform,
    this.origin,
    this.alignment,
    this.transformHitTests = true,
    this.filterQuality,
    super.child,
  });

  Transform.rotate({
    super.key,
    required double angle,
    this.origin,
    this.alignment = Alignment.center,
    this.transformHitTests = true,
    this.filterQuality,
    super.child,
  }) : transform = _computeRotation(angle);

  Transform.translate({
    super.key,
    required Offset offset,
    this.transformHitTests = true,
    this.filterQuality,
    super.child,
  })  : transform = Matrix4.translationValues(offset.dx, offset.dy, 0.0),
        origin = null,
        alignment = null;

  Transform.scale({
    super.key,
    double? scale,
    double? scaleX,
    double? scaleY,
    this.origin,
    this.alignment = Alignment.center,
    this.transformHitTests = true,
    this.filterQuality,
    super.child,
  })  : assert(!(scale == null && scaleX == null && scaleY == null),
            "At least one of 'scale', 'scaleX' and 'scaleY' is required to be non-null"),
        assert(scale == null || (scaleX == null && scaleY == null),
            "If 'scale' is non-null then 'scaleX' and 'scaleY' must be left null"),
        transform = Matrix4.diagonal3Values(
            scale ?? scaleX ?? 1.0, scale ?? scaleY ?? 1.0, 1.0);

  Transform.flip({
    super.key,
    bool flipX = false,
    bool flipY = false,
    this.origin,
    this.transformHitTests = true,
    this.filterQuality,
    super.child,
  })  : alignment = Alignment.center,
        transform = Matrix4.diagonal3Values(
            flipX ? -1.0 : 1.0, flipY ? -1.0 : 1.0, 1.0);

  // Computes a rotation matrix for an angle in radians, attempting to keep rotations
  // at integral values for angles of 0, π/2, π, 3π/2.
  static Matrix4 _computeRotation(double radians) {
    assert(radians.isFinite,
        'Cannot compute the rotation matrix for a non-finite angle: $radians');
    if (radians == 0.0) {
      return Matrix4.identity();
    }
    final double sin = math.sin(radians);
    if (sin == 1.0) {
      return _createZRotation(1.0, 0.0);
    }
    if (sin == -1.0) {
      return _createZRotation(-1.0, 0.0);
    }
    final double cos = math.cos(radians);
    if (cos == -1.0) {
      return _createZRotation(0.0, -1.0);
    }
    return _createZRotation(sin, cos);
  }

  static Matrix4 _createZRotation(double sin, double cos) {
    final Matrix4 result = Matrix4.zero();
    result.storage[0] = cos;
    result.storage[1] = sin;
    result.storage[4] = -sin;
    result.storage[5] = cos;
    result.storage[10] = 1.0;
    result.storage[15] = 1.0;
    return result;
  }

  final Matrix4 transform;

  final Offset? origin;

  final AlignmentGeometry? alignment;

  final bool transformHitTests;

  final FilterQuality? filterQuality;

  @override
  RenderTransform createRenderObject(BuildContext context) {
    return RenderTransform(
      transform: transform,
      origin: origin,
      alignment: alignment,
      textDirection: Directionality.maybeOf(context),
      transformHitTests: transformHitTests,
      filterQuality: filterQuality,
    );
  }

  @override
  void updateRenderObject(BuildContext context, RenderTransform renderObject) {
    renderObject
      ..transform = transform
      ..origin = origin
      ..alignment = alignment
      ..textDirection = Directionality.maybeOf(context)
      ..transformHitTests = transformHitTests
      ..filterQuality = filterQuality;
  }
}

class CompositedTransformTarget extends SingleChildRenderObjectWidget {
  const CompositedTransformTarget({
    super.key,
    required this.link,
    super.child,
  });

  final LayerLink link;

  @override
  RenderLeaderLayer createRenderObject(BuildContext context) {
    return RenderLeaderLayer(
      link: link,
    );
  }

  @override
  void updateRenderObject(
      BuildContext context, RenderLeaderLayer renderObject) {
    renderObject.link = link;
  }
}

class CompositedTransformFollower extends SingleChildRenderObjectWidget {
  const CompositedTransformFollower({
    super.key,
    required this.link,
    this.showWhenUnlinked = true,
    this.offset = Offset.zero,
    this.targetAnchor = Alignment.topLeft,
    this.followerAnchor = Alignment.topLeft,
    super.child,
  });

  final LayerLink link;

  final bool showWhenUnlinked;

  final Alignment targetAnchor;

  final Alignment followerAnchor;

  final Offset offset;

  @override
  RenderFollowerLayer createRenderObject(BuildContext context) {
    return RenderFollowerLayer(
      link: link,
      showWhenUnlinked: showWhenUnlinked,
      offset: offset,
      leaderAnchor: targetAnchor,
      followerAnchor: followerAnchor,
    );
  }

  @override
  void updateRenderObject(
      BuildContext context, RenderFollowerLayer renderObject) {
    renderObject
      ..link = link
      ..showWhenUnlinked = showWhenUnlinked
      ..offset = offset
      ..leaderAnchor = targetAnchor
      ..followerAnchor = followerAnchor;
  }
}

class FittedBox extends SingleChildRenderObjectWidget {
  const FittedBox({
    super.key,
    this.fit = BoxFit.contain,
    this.alignment = Alignment.center,
    this.clipBehavior = Clip.none,
    super.child,
  });

  final BoxFit fit;

  final AlignmentGeometry alignment;

  final Clip clipBehavior;

  @override
  RenderFittedBox createRenderObject(BuildContext context) {
    return RenderFittedBox(
      fit: fit,
      alignment: alignment,
      textDirection: Directionality.maybeOf(context),
      clipBehavior: clipBehavior,
    );
  }

  @override
  void updateRenderObject(BuildContext context, RenderFittedBox renderObject) {
    renderObject
      ..fit = fit
      ..alignment = alignment
      ..textDirection = Directionality.maybeOf(context)
      ..clipBehavior = clipBehavior;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(EnumProperty<BoxFit>('fit', fit));
    properties
        .add(DiagnosticsProperty<AlignmentGeometry>('alignment', alignment));
  }
}

class FractionalTranslation extends SingleChildRenderObjectWidget {
  const FractionalTranslation({
    super.key,
    required this.translation,
    this.transformHitTests = true,
    super.child,
  });

  final Offset translation;

  final bool transformHitTests;

  @override
  RenderFractionalTranslation createRenderObject(BuildContext context) {
    return RenderFractionalTranslation(
      translation: translation,
      transformHitTests: transformHitTests,
    );
  }

  @override
  void updateRenderObject(
      BuildContext context, RenderFractionalTranslation renderObject) {
    renderObject
      ..translation = translation
      ..transformHitTests = transformHitTests;
  }
}

class RotatedBox extends SingleChildRenderObjectWidget {
  const RotatedBox({
    super.key,
    required this.quarterTurns,
    super.child,
  });

  final int quarterTurns;

  @override
  RenderRotatedBox createRenderObject(BuildContext context) =>
      RenderRotatedBox(quarterTurns: quarterTurns);

  @override
  void updateRenderObject(BuildContext context, RenderRotatedBox renderObject) {
    renderObject.quarterTurns = quarterTurns;
  }
}

class Padding extends SingleChildRenderObjectWidget {
  const Padding({
    super.key,
    required this.padding,
    super.child,
  });

  final EdgeInsetsGeometry padding;

  @override
  RenderPadding createRenderObject(BuildContext context) {
    return RenderPadding(
      padding: padding,
      textDirection: Directionality.maybeOf(context),
    );
  }

  @override
  void updateRenderObject(BuildContext context, RenderPadding renderObject) {
    renderObject
      ..padding = padding
      ..textDirection = Directionality.maybeOf(context);
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<EdgeInsetsGeometry>('padding', padding));
  }
}

class Align extends SingleChildRenderObjectWidget {
  const Align({
    super.key,
    this.alignment = Alignment.center,
    this.widthFactor,
    this.heightFactor,
    super.child,
  })  : assert(widthFactor == null || widthFactor >= 0.0),
        assert(heightFactor == null || heightFactor >= 0.0);

  final AlignmentGeometry alignment;

  final double? widthFactor;

  final double? heightFactor;

  @override
  RenderPositionedBox createRenderObject(BuildContext context) {
    return RenderPositionedBox(
      alignment: alignment,
      widthFactor: widthFactor,
      heightFactor: heightFactor,
      textDirection: Directionality.maybeOf(context),
    );
  }

  @override
  void updateRenderObject(
      BuildContext context, RenderPositionedBox renderObject) {
    renderObject
      ..alignment = alignment
      ..widthFactor = widthFactor
      ..heightFactor = heightFactor
      ..textDirection = Directionality.maybeOf(context);
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
        .add(DiagnosticsProperty<AlignmentGeometry>('alignment', alignment));
    properties
        .add(DoubleProperty('widthFactor', widthFactor, defaultValue: null));
    properties
        .add(DoubleProperty('heightFactor', heightFactor, defaultValue: null));
  }
}

class Center extends Align {
  const Center({super.key, super.widthFactor, super.heightFactor, super.child});
}

class CustomSingleChildLayout extends SingleChildRenderObjectWidget {
  const CustomSingleChildLayout({
    super.key,
    required this.delegate,
    super.child,
  });

  final SingleChildLayoutDelegate delegate;

  @override
  RenderCustomSingleChildLayoutBox createRenderObject(BuildContext context) {
    return RenderCustomSingleChildLayoutBox(delegate: delegate);
  }

  @override
  void updateRenderObject(
      BuildContext context, RenderCustomSingleChildLayoutBox renderObject) {
    renderObject.delegate = delegate;
  }
}

class LayoutId extends ParentDataWidget<MultiChildLayoutParentData> {
  LayoutId({
    Key? key,
    required this.id,
    required super.child,
  }) : super(key: key ?? ValueKey<Object>(id));

  final Object id;

  @override
  void applyParentData(RenderObject renderObject) {
    assert(renderObject.parentData is MultiChildLayoutParentData);
    final MultiChildLayoutParentData parentData =
        renderObject.parentData! as MultiChildLayoutParentData;
    if (parentData.id != id) {
      parentData.id = id;
      final RenderObject? targetParent = renderObject.parent;
      if (targetParent is RenderObject) {
        targetParent.markNeedsLayout();
      }
    }
  }

  @override
  Type get debugTypicalAncestorWidgetClass => CustomMultiChildLayout;

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<Object>('id', id));
  }
}

class CustomMultiChildLayout extends MultiChildRenderObjectWidget {
  const CustomMultiChildLayout({
    super.key,
    required this.delegate,
    super.children,
  });

  final MultiChildLayoutDelegate delegate;

  @override
  RenderCustomMultiChildLayoutBox createRenderObject(BuildContext context) {
    return RenderCustomMultiChildLayoutBox(delegate: delegate);
  }

  @override
  void updateRenderObject(
      BuildContext context, RenderCustomMultiChildLayoutBox renderObject) {
    renderObject.delegate = delegate;
  }
}

class SizedBox extends SingleChildRenderObjectWidget {
  const SizedBox({super.key, this.width, this.height, super.child});

  const SizedBox.expand({super.key, super.child})
      : width = double.infinity,
        height = double.infinity;

  const SizedBox.shrink({super.key, super.child})
      : width = 0.0,
        height = 0.0;

  SizedBox.fromSize({super.key, super.child, Size? size})
      : width = size?.width,
        height = size?.height;

  const SizedBox.square({super.key, super.child, double? dimension})
      : width = dimension,
        height = dimension;

  final double? width;

  final double? height;

  @override
  RenderConstrainedBox createRenderObject(BuildContext context) {
    return RenderConstrainedBox(
      additionalConstraints: _additionalConstraints,
    );
  }

  BoxConstraints get _additionalConstraints {
    return BoxConstraints.tightFor(width: width, height: height);
  }

  @override
  void updateRenderObject(
      BuildContext context, RenderConstrainedBox renderObject) {
    renderObject.additionalConstraints = _additionalConstraints;
  }

  @override
  String toStringShort() {
    final String type;
    if (width == double.infinity && height == double.infinity) {
      type = '${objectRuntimeType(this, 'SizedBox')}.expand';
    } else if (width == 0.0 && height == 0.0) {
      type = '${objectRuntimeType(this, 'SizedBox')}.shrink';
    } else {
      type = objectRuntimeType(this, 'SizedBox');
    }
    return key == null ? type : '$type-$key';
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    final DiagnosticLevel level;
    if ((width == double.infinity && height == double.infinity) ||
        (width == 0.0 && height == 0.0)) {
      level = DiagnosticLevel.hidden;
    } else {
      level = DiagnosticLevel.info;
    }
    properties
        .add(DoubleProperty('width', width, defaultValue: null, level: level));
    properties.add(
        DoubleProperty('height', height, defaultValue: null, level: level));
  }
}

class ConstrainedBox extends SingleChildRenderObjectWidget {
  ConstrainedBox({
    super.key,
    required this.constraints,
    super.child,
  }) : assert(constraints.debugAssertIsValid());

  final BoxConstraints constraints;

  @override
  RenderConstrainedBox createRenderObject(BuildContext context) {
    return RenderConstrainedBox(additionalConstraints: constraints);
  }

  @override
  void updateRenderObject(
      BuildContext context, RenderConstrainedBox renderObject) {
    renderObject.additionalConstraints = constraints;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<BoxConstraints>(
        'constraints', constraints,
        showName: false));
  }
}

class ConstraintsTransformBox extends SingleChildRenderObjectWidget {
  const ConstraintsTransformBox({
    super.key,
    super.child,
    this.textDirection,
    this.alignment = Alignment.center,
    required this.constraintsTransform,
    this.clipBehavior = Clip.none,
    String debugTransformType = '',
  }) : _debugTransformLabel = debugTransformType;

  static BoxConstraints unmodified(BoxConstraints constraints) => constraints;

  static BoxConstraints unconstrained(BoxConstraints constraints) =>
      const BoxConstraints();

  static BoxConstraints widthUnconstrained(BoxConstraints constraints) =>
      constraints.heightConstraints();

  static BoxConstraints heightUnconstrained(BoxConstraints constraints) =>
      constraints.widthConstraints();

  static BoxConstraints maxHeightUnconstrained(BoxConstraints constraints) =>
      constraints.copyWith(maxHeight: double.infinity);

  static BoxConstraints maxWidthUnconstrained(BoxConstraints constraints) =>
      constraints.copyWith(maxWidth: double.infinity);

  static BoxConstraints maxUnconstrained(BoxConstraints constraints) =>
      constraints.copyWith(
          maxWidth: double.infinity, maxHeight: double.infinity);

  static final Map<BoxConstraintsTransform, String> _debugKnownTransforms =
      <BoxConstraintsTransform, String>{
    unmodified: 'unmodified',
    unconstrained: 'unconstrained',
    widthUnconstrained: 'width constraints removed',
    heightUnconstrained: 'height constraints removed',
    maxWidthUnconstrained: 'maxWidth constraint removed',
    maxHeightUnconstrained: 'maxHeight constraint removed',
    maxUnconstrained: 'maxWidth & maxHeight constraints removed',
  };

  final TextDirection? textDirection;

  final AlignmentGeometry alignment;

  final BoxConstraintsTransform constraintsTransform;

  final Clip clipBehavior;

  final String _debugTransformLabel;

  @override
  RenderConstraintsTransformBox createRenderObject(BuildContext context) {
    return RenderConstraintsTransformBox(
      textDirection: textDirection ?? Directionality.maybeOf(context),
      alignment: alignment,
      constraintsTransform: constraintsTransform,
      clipBehavior: clipBehavior,
    );
  }

  @override
  void updateRenderObject(BuildContext context,
      covariant RenderConstraintsTransformBox renderObject) {
    renderObject
      ..textDirection = textDirection ?? Directionality.maybeOf(context)
      ..constraintsTransform = constraintsTransform
      ..alignment = alignment
      ..clipBehavior = clipBehavior;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
        .add(DiagnosticsProperty<AlignmentGeometry>('alignment', alignment));
    properties.add(EnumProperty<TextDirection>('textDirection', textDirection,
        defaultValue: null));

    final String? debugTransformLabel = _debugTransformLabel.isNotEmpty
        ? _debugTransformLabel
        : _debugKnownTransforms[constraintsTransform];

    if (debugTransformLabel != null) {
      properties.add(DiagnosticsProperty<String>(
          'constraints transform', debugTransformLabel));
    }
  }
}

class UnconstrainedBox extends StatelessWidget {
  const UnconstrainedBox({
    super.key,
    this.child,
    this.textDirection,
    this.alignment = Alignment.center,
    this.constrainedAxis,
    this.clipBehavior = Clip.none,
  });

  final TextDirection? textDirection;

  final AlignmentGeometry alignment;

  final Axis? constrainedAxis;

  final Clip clipBehavior;

  final Widget? child;

  BoxConstraintsTransform _axisToTransform(Axis? constrainedAxis) {
    if (constrainedAxis != null) {
      switch (constrainedAxis) {
        case Axis.horizontal:
          return ConstraintsTransformBox.heightUnconstrained;
        case Axis.vertical:
          return ConstraintsTransformBox.widthUnconstrained;
      }
    } else {
      return ConstraintsTransformBox.unconstrained;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ConstraintsTransformBox(
      textDirection: textDirection,
      alignment: alignment,
      clipBehavior: clipBehavior,
      constraintsTransform: _axisToTransform(constrainedAxis),
      child: child,
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
        .add(DiagnosticsProperty<AlignmentGeometry>('alignment', alignment));
    properties.add(EnumProperty<Axis>('constrainedAxis', constrainedAxis,
        defaultValue: null));
    properties.add(EnumProperty<TextDirection>('textDirection', textDirection,
        defaultValue: null));
  }
}

class FractionallySizedBox extends SingleChildRenderObjectWidget {
  const FractionallySizedBox({
    super.key,
    this.alignment = Alignment.center,
    this.widthFactor,
    this.heightFactor,
    super.child,
  })  : assert(widthFactor == null || widthFactor >= 0.0),
        assert(heightFactor == null || heightFactor >= 0.0);

  final double? widthFactor;

  final double? heightFactor;

  final AlignmentGeometry alignment;

  @override
  RenderFractionallySizedOverflowBox createRenderObject(BuildContext context) {
    return RenderFractionallySizedOverflowBox(
      alignment: alignment,
      widthFactor: widthFactor,
      heightFactor: heightFactor,
      textDirection: Directionality.maybeOf(context),
    );
  }

  @override
  void updateRenderObject(
      BuildContext context, RenderFractionallySizedOverflowBox renderObject) {
    renderObject
      ..alignment = alignment
      ..widthFactor = widthFactor
      ..heightFactor = heightFactor
      ..textDirection = Directionality.maybeOf(context);
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
        .add(DiagnosticsProperty<AlignmentGeometry>('alignment', alignment));
    properties
        .add(DoubleProperty('widthFactor', widthFactor, defaultValue: null));
    properties
        .add(DoubleProperty('heightFactor', heightFactor, defaultValue: null));
  }
}

class LimitedBox extends SingleChildRenderObjectWidget {
  const LimitedBox({
    super.key,
    this.maxWidth = double.infinity,
    this.maxHeight = double.infinity,
    super.child,
  })  : assert(maxWidth >= 0.0),
        assert(maxHeight >= 0.0);

  final double maxWidth;

  final double maxHeight;

  @override
  RenderLimitedBox createRenderObject(BuildContext context) {
    return RenderLimitedBox(
      maxWidth: maxWidth,
      maxHeight: maxHeight,
    );
  }

  @override
  void updateRenderObject(BuildContext context, RenderLimitedBox renderObject) {
    renderObject
      ..maxWidth = maxWidth
      ..maxHeight = maxHeight;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(
        DoubleProperty('maxWidth', maxWidth, defaultValue: double.infinity));
    properties.add(
        DoubleProperty('maxHeight', maxHeight, defaultValue: double.infinity));
  }
}

class OverflowBox extends SingleChildRenderObjectWidget {
  const OverflowBox({
    super.key,
    this.alignment = Alignment.center,
    this.minWidth,
    this.maxWidth,
    this.minHeight,
    this.maxHeight,
    super.child,
  });

  final AlignmentGeometry alignment;

  final double? minWidth;

  final double? maxWidth;

  final double? minHeight;

  final double? maxHeight;

  @override
  RenderConstrainedOverflowBox createRenderObject(BuildContext context) {
    return RenderConstrainedOverflowBox(
      alignment: alignment,
      minWidth: minWidth,
      maxWidth: maxWidth,
      minHeight: minHeight,
      maxHeight: maxHeight,
      textDirection: Directionality.maybeOf(context),
    );
  }

  @override
  void updateRenderObject(
      BuildContext context, RenderConstrainedOverflowBox renderObject) {
    renderObject
      ..alignment = alignment
      ..minWidth = minWidth
      ..maxWidth = maxWidth
      ..minHeight = minHeight
      ..maxHeight = maxHeight
      ..textDirection = Directionality.maybeOf(context);
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
        .add(DiagnosticsProperty<AlignmentGeometry>('alignment', alignment));
    properties.add(DoubleProperty('minWidth', minWidth, defaultValue: null));
    properties.add(DoubleProperty('maxWidth', maxWidth, defaultValue: null));
    properties.add(DoubleProperty('minHeight', minHeight, defaultValue: null));
    properties.add(DoubleProperty('maxHeight', maxHeight, defaultValue: null));
  }
}

class SizedOverflowBox extends SingleChildRenderObjectWidget {
  const SizedOverflowBox({
    super.key,
    required this.size,
    this.alignment = Alignment.center,
    super.child,
  });

  final AlignmentGeometry alignment;

  final Size size;

  @override
  RenderSizedOverflowBox createRenderObject(BuildContext context) {
    return RenderSizedOverflowBox(
      alignment: alignment,
      requestedSize: size,
      textDirection: Directionality.of(context),
    );
  }

  @override
  void updateRenderObject(
      BuildContext context, RenderSizedOverflowBox renderObject) {
    renderObject
      ..alignment = alignment
      ..requestedSize = size
      ..textDirection = Directionality.of(context);
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
        .add(DiagnosticsProperty<AlignmentGeometry>('alignment', alignment));
    properties.add(DiagnosticsProperty<Size>('size', size, defaultValue: null));
  }
}

class Offstage extends SingleChildRenderObjectWidget {
  const Offstage({super.key, this.offstage = true, super.child});

  final bool offstage;

  @override
  RenderOffstage createRenderObject(BuildContext context) =>
      RenderOffstage(offstage: offstage);

  @override
  void updateRenderObject(BuildContext context, RenderOffstage renderObject) {
    renderObject.offstage = offstage;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<bool>('offstage', offstage));
  }

  @override
  SingleChildRenderObjectElement createElement() => _OffstageElement(this);
}

class _OffstageElement extends SingleChildRenderObjectElement {
  _OffstageElement(Offstage super.widget);

  @override
  void debugVisitOnstageChildren(ElementVisitor visitor) {
    if (!(widget as Offstage).offstage) {
      super.debugVisitOnstageChildren(visitor);
    }
  }
}

class AspectRatio extends SingleChildRenderObjectWidget {
  const AspectRatio({
    super.key,
    required this.aspectRatio,
    super.child,
  }) : assert(aspectRatio > 0.0);

  final double aspectRatio;

  @override
  RenderAspectRatio createRenderObject(BuildContext context) =>
      RenderAspectRatio(aspectRatio: aspectRatio);

  @override
  void updateRenderObject(
      BuildContext context, RenderAspectRatio renderObject) {
    renderObject.aspectRatio = aspectRatio;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DoubleProperty('aspectRatio', aspectRatio));
  }
}

class IntrinsicWidth extends SingleChildRenderObjectWidget {
  const IntrinsicWidth(
      {super.key, this.stepWidth, this.stepHeight, super.child})
      : assert(stepWidth == null || stepWidth >= 0.0),
        assert(stepHeight == null || stepHeight >= 0.0);

  final double? stepWidth;

  final double? stepHeight;

  double? get _stepWidth => stepWidth == 0.0 ? null : stepWidth;
  double? get _stepHeight => stepHeight == 0.0 ? null : stepHeight;

  @override
  RenderIntrinsicWidth createRenderObject(BuildContext context) {
    return RenderIntrinsicWidth(stepWidth: _stepWidth, stepHeight: _stepHeight);
  }

  @override
  void updateRenderObject(
      BuildContext context, RenderIntrinsicWidth renderObject) {
    renderObject
      ..stepWidth = _stepWidth
      ..stepHeight = _stepHeight;
  }
}

class IntrinsicHeight extends SingleChildRenderObjectWidget {
  const IntrinsicHeight({super.key, super.child});

  @override
  RenderIntrinsicHeight createRenderObject(BuildContext context) =>
      RenderIntrinsicHeight();
}

class Baseline extends SingleChildRenderObjectWidget {
  const Baseline({
    super.key,
    required this.baseline,
    required this.baselineType,
    super.child,
  });

  final double baseline;

  final TextBaseline baselineType;

  @override
  RenderBaseline createRenderObject(BuildContext context) {
    return RenderBaseline(baseline: baseline, baselineType: baselineType);
  }

  @override
  void updateRenderObject(BuildContext context, RenderBaseline renderObject) {
    renderObject
      ..baseline = baseline
      ..baselineType = baselineType;
  }
}

class IgnoreBaseline extends SingleChildRenderObjectWidget {
  const IgnoreBaseline({
    super.key,
    super.child,
  });

  @override
  RenderIgnoreBaseline createRenderObject(BuildContext context) {
    return RenderIgnoreBaseline();
  }
}

// SLIVERS

class SliverToBoxAdapter extends SingleChildRenderObjectWidget {
  const SliverToBoxAdapter({
    super.key,
    super.child,
  });

  @override
  RenderSliverToBoxAdapter createRenderObject(BuildContext context) =>
      RenderSliverToBoxAdapter();
}

class SliverPadding extends SingleChildRenderObjectWidget {
  const SliverPadding({
    super.key,
    required this.padding,
    Widget? sliver,
  }) : super(child: sliver);

  final EdgeInsetsGeometry padding;

  @override
  RenderSliverPadding createRenderObject(BuildContext context) {
    return RenderSliverPadding(
      padding: padding,
      textDirection: Directionality.of(context),
    );
  }

  @override
  void updateRenderObject(
      BuildContext context, RenderSliverPadding renderObject) {
    renderObject
      ..padding = padding
      ..textDirection = Directionality.of(context);
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<EdgeInsetsGeometry>('padding', padding));
  }
}

// LAYOUT NODES

AxisDirection getAxisDirectionFromAxisReverseAndDirectionality(
  BuildContext context,
  Axis axis,
  bool reverse,
) {
  switch (axis) {
    case Axis.horizontal:
      assert(debugCheckHasDirectionality(context));
      final TextDirection textDirection = Directionality.of(context);
      final AxisDirection axisDirection =
          textDirectionToAxisDirection(textDirection);
      return reverse ? flipAxisDirection(axisDirection) : axisDirection;
    case Axis.vertical:
      return reverse ? AxisDirection.up : AxisDirection.down;
  }
}

class ListBody extends MultiChildRenderObjectWidget {
  const ListBody({
    super.key,
    this.mainAxis = Axis.vertical,
    this.reverse = false,
    super.children,
  });

  final Axis mainAxis;

  final bool reverse;

  AxisDirection _getDirection(BuildContext context) {
    return getAxisDirectionFromAxisReverseAndDirectionality(
        context, mainAxis, reverse);
  }

  @override
  RenderListBody createRenderObject(BuildContext context) {
    return RenderListBody(axisDirection: _getDirection(context));
  }

  @override
  void updateRenderObject(BuildContext context, RenderListBody renderObject) {
    renderObject.axisDirection = _getDirection(context);
  }
}

class Stack extends MultiChildRenderObjectWidget {
  const Stack({
    super.key,
    this.alignment = AlignmentDirectional.topStart,
    this.textDirection,
    this.fit = StackFit.loose,
    this.clipBehavior = Clip.hardEdge,
    super.children,
  });

  final AlignmentGeometry alignment;

  final TextDirection? textDirection;

  final StackFit fit;

  final Clip clipBehavior;

  bool _debugCheckHasDirectionality(BuildContext context) {
    if (alignment is AlignmentDirectional && textDirection == null) {
      assert(debugCheckHasDirectionality(
        context,
        why: "to resolve the 'alignment' argument",
        hint: alignment == AlignmentDirectional.topStart
            ? "The default value for 'alignment' is AlignmentDirectional.topStart, which requires a text direction."
            : null,
        alternative:
            "Instead of providing a Directionality widget, another solution would be passing a non-directional 'alignment', or an explicit 'textDirection', to the $runtimeType.",
      ));
    }
    return true;
  }

  @override
  RenderStack createRenderObject(BuildContext context) {
    assert(_debugCheckHasDirectionality(context));
    return RenderStack(
      alignment: alignment,
      textDirection: textDirection ?? Directionality.maybeOf(context),
      fit: fit,
      clipBehavior: clipBehavior,
    );
  }

  @override
  void updateRenderObject(BuildContext context, RenderStack renderObject) {
    assert(_debugCheckHasDirectionality(context));
    renderObject
      ..alignment = alignment
      ..textDirection = textDirection ?? Directionality.maybeOf(context)
      ..fit = fit
      ..clipBehavior = clipBehavior;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
        .add(DiagnosticsProperty<AlignmentGeometry>('alignment', alignment));
    properties.add(EnumProperty<TextDirection>('textDirection', textDirection,
        defaultValue: null));
    properties.add(EnumProperty<StackFit>('fit', fit));
    properties.add(EnumProperty<Clip>('clipBehavior', clipBehavior,
        defaultValue: Clip.hardEdge));
  }
}

class IndexedStack extends StatelessWidget {
  const IndexedStack({
    super.key,
    this.alignment = AlignmentDirectional.topStart,
    this.textDirection,
    this.clipBehavior = Clip.hardEdge,
    this.sizing = StackFit.loose,
    this.index = 0,
    this.children = const <Widget>[],
  });

  final AlignmentGeometry alignment;

  final TextDirection? textDirection;

  final Clip clipBehavior;

  final StackFit sizing;

  final int? index;

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final List<Widget> wrappedChildren =
        List<Widget>.generate(children.length, (int i) {
      return Visibility.maintain(
        visible: i == index,
        child: children[i],
      );
    });
    return _RawIndexedStack(
      alignment: alignment,
      textDirection: textDirection,
      clipBehavior: clipBehavior,
      sizing: sizing,
      index: index,
      children: wrappedChildren,
    );
  }
}

class _RawIndexedStack extends Stack {
  const _RawIndexedStack({
    super.alignment,
    super.textDirection,
    super.clipBehavior,
    StackFit sizing = StackFit.loose,
    this.index = 0,
    super.children,
  }) : super(fit: sizing);

  final int? index;

  @override
  RenderIndexedStack createRenderObject(BuildContext context) {
    assert(_debugCheckHasDirectionality(context));
    return RenderIndexedStack(
      index: index,
      fit: fit,
      clipBehavior: clipBehavior,
      alignment: alignment,
      textDirection: textDirection ?? Directionality.maybeOf(context),
    );
  }

  @override
  void updateRenderObject(
      BuildContext context, RenderIndexedStack renderObject) {
    assert(_debugCheckHasDirectionality(context));
    renderObject
      ..index = index
      ..fit = fit
      ..clipBehavior = clipBehavior
      ..alignment = alignment
      ..textDirection = textDirection ?? Directionality.maybeOf(context);
  }

  @override
  MultiChildRenderObjectElement createElement() {
    return _IndexedStackElement(this);
  }
}

class _IndexedStackElement extends MultiChildRenderObjectElement {
  _IndexedStackElement(_RawIndexedStack super.widget);

  @override
  _RawIndexedStack get widget => super.widget as _RawIndexedStack;

  @override
  void debugVisitOnstageChildren(ElementVisitor visitor) {
    final int? index = widget.index;
    // If the index is null, no child is onstage. Otherwise, only the child at
    // the selected index is.
    if (index != null && children.isNotEmpty) {
      visitor(children.elementAt(index));
    }
  }
}

class Positioned extends ParentDataWidget<StackParentData> {
  const Positioned({
    super.key,
    this.left,
    this.top,
    this.right,
    this.bottom,
    this.width,
    this.height,
    required super.child,
  })  : assert(left == null || right == null || width == null),
        assert(top == null || bottom == null || height == null);

  Positioned.fromRect({
    super.key,
    required Rect rect,
    required super.child,
  })  : left = rect.left,
        top = rect.top,
        width = rect.width,
        height = rect.height,
        right = null,
        bottom = null;

  Positioned.fromRelativeRect({
    super.key,
    required RelativeRect rect,
    required super.child,
  })  : left = rect.left,
        top = rect.top,
        right = rect.right,
        bottom = rect.bottom,
        width = null,
        height = null;

  const Positioned.fill({
    super.key,
    this.left = 0.0,
    this.top = 0.0,
    this.right = 0.0,
    this.bottom = 0.0,
    required super.child,
  })  : width = null,
        height = null;

  factory Positioned.directional({
    Key? key,
    required TextDirection textDirection,
    double? start,
    double? top,
    double? end,
    double? bottom,
    double? width,
    double? height,
    required Widget child,
  }) {
    double? left;
    double? right;
    switch (textDirection) {
      case TextDirection.rtl:
        left = end;
        right = start;
      case TextDirection.ltr:
        left = start;
        right = end;
    }
    return Positioned(
      key: key,
      left: left,
      top: top,
      right: right,
      bottom: bottom,
      width: width,
      height: height,
      child: child,
    );
  }

  final double? left;

  final double? top;

  final double? right;

  final double? bottom;

  final double? width;

  final double? height;

  @override
  void applyParentData(RenderObject renderObject) {
    assert(renderObject.parentData is StackParentData);
    final StackParentData parentData =
        renderObject.parentData! as StackParentData;
    bool needsLayout = false;

    if (parentData.left != left) {
      parentData.left = left;
      needsLayout = true;
    }

    if (parentData.top != top) {
      parentData.top = top;
      needsLayout = true;
    }

    if (parentData.right != right) {
      parentData.right = right;
      needsLayout = true;
    }

    if (parentData.bottom != bottom) {
      parentData.bottom = bottom;
      needsLayout = true;
    }

    if (parentData.width != width) {
      parentData.width = width;
      needsLayout = true;
    }

    if (parentData.height != height) {
      parentData.height = height;
      needsLayout = true;
    }

    if (needsLayout) {
      final RenderObject? targetParent = renderObject.parent;
      if (targetParent is RenderObject) {
        targetParent.markNeedsLayout();
      }
    }
  }

  @override
  Type get debugTypicalAncestorWidgetClass => Stack;

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DoubleProperty('left', left, defaultValue: null));
    properties.add(DoubleProperty('top', top, defaultValue: null));
    properties.add(DoubleProperty('right', right, defaultValue: null));
    properties.add(DoubleProperty('bottom', bottom, defaultValue: null));
    properties.add(DoubleProperty('width', width, defaultValue: null));
    properties.add(DoubleProperty('height', height, defaultValue: null));
  }
}

class PositionedDirectional extends StatelessWidget {
  const PositionedDirectional({
    super.key,
    this.start,
    this.top,
    this.end,
    this.bottom,
    this.width,
    this.height,
    required this.child,
  });

  final double? start;

  final double? top;

  final double? end;

  final double? bottom;

  final double? width;

  final double? height;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Positioned.directional(
      textDirection: Directionality.of(context),
      start: start,
      top: top,
      end: end,
      bottom: bottom,
      width: width,
      height: height,
      child: child,
    );
  }
}

class Flex extends MultiChildRenderObjectWidget {
  const Flex({
    super.key,
    required this.direction,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.mainAxisSize = MainAxisSize.max,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.textDirection,
    this.verticalDirection = VerticalDirection.down,
    this.textBaseline, // NO DEFAULT: we don't know what the text's baseline should be
    this.clipBehavior = Clip.none,
    super.children,
  }) : assert(
            !identical(crossAxisAlignment, CrossAxisAlignment.baseline) ||
                textBaseline != null,
            'textBaseline is required if you specify the crossAxisAlignment with CrossAxisAlignment.baseline');
  // Cannot use == in the assert above instead of identical because of https://github.com/dart-lang/language/issues/1811.

  final Axis direction;

  final MainAxisAlignment mainAxisAlignment;

  final MainAxisSize mainAxisSize;

  final CrossAxisAlignment crossAxisAlignment;

  final TextDirection? textDirection;

  final VerticalDirection verticalDirection;

  final TextBaseline? textBaseline;

  final Clip clipBehavior;

  bool get _needTextDirection {
    switch (direction) {
      case Axis.horizontal:
        return true; // because it affects the layout order.
      case Axis.vertical:
        return crossAxisAlignment == CrossAxisAlignment.start ||
            crossAxisAlignment == CrossAxisAlignment.end;
    }
  }

  @protected
  TextDirection? getEffectiveTextDirection(BuildContext context) {
    return textDirection ??
        (_needTextDirection ? Directionality.maybeOf(context) : null);
  }

  @override
  RenderFlex createRenderObject(BuildContext context) {
    return RenderFlex(
      direction: direction,
      mainAxisAlignment: mainAxisAlignment,
      mainAxisSize: mainAxisSize,
      crossAxisAlignment: crossAxisAlignment,
      textDirection: getEffectiveTextDirection(context),
      verticalDirection: verticalDirection,
      textBaseline: textBaseline,
      clipBehavior: clipBehavior,
    );
  }

  @override
  void updateRenderObject(
      BuildContext context, covariant RenderFlex renderObject) {
    renderObject
      ..direction = direction
      ..mainAxisAlignment = mainAxisAlignment
      ..mainAxisSize = mainAxisSize
      ..crossAxisAlignment = crossAxisAlignment
      ..textDirection = getEffectiveTextDirection(context)
      ..verticalDirection = verticalDirection
      ..textBaseline = textBaseline
      ..clipBehavior = clipBehavior;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(EnumProperty<Axis>('direction', direction));
    properties.add(EnumProperty<MainAxisAlignment>(
        'mainAxisAlignment', mainAxisAlignment));
    properties.add(EnumProperty<MainAxisSize>('mainAxisSize', mainAxisSize,
        defaultValue: MainAxisSize.max));
    properties.add(EnumProperty<CrossAxisAlignment>(
        'crossAxisAlignment', crossAxisAlignment));
    properties.add(EnumProperty<TextDirection>('textDirection', textDirection,
        defaultValue: null));
    properties.add(EnumProperty<VerticalDirection>(
        'verticalDirection', verticalDirection,
        defaultValue: VerticalDirection.down));
    properties.add(EnumProperty<TextBaseline>('textBaseline', textBaseline,
        defaultValue: null));
  }
}

class Row extends Flex {
  const Row({
    super.key,
    super.mainAxisAlignment,
    super.mainAxisSize,
    super.crossAxisAlignment,
    super.textDirection,
    super.verticalDirection,
    super.textBaseline, // NO DEFAULT: we don't know what the text's baseline should be
    super.children,
  }) : super(
          direction: Axis.horizontal,
        );
}

class Column extends Flex {
  const Column({
    super.key,
    super.mainAxisAlignment,
    super.mainAxisSize,
    super.crossAxisAlignment,
    super.textDirection,
    super.verticalDirection,
    super.textBaseline,
    super.children,
  }) : super(
          direction: Axis.vertical,
        );
}

class Flexible extends ParentDataWidget<FlexParentData> {
  const Flexible({
    super.key,
    this.flex = 1,
    this.fit = FlexFit.loose,
    required super.child,
  });

  final int flex;

  final FlexFit fit;

  @override
  void applyParentData(RenderObject renderObject) {
    assert(renderObject.parentData is FlexParentData);
    final FlexParentData parentData =
        renderObject.parentData! as FlexParentData;
    bool needsLayout = false;

    if (parentData.flex != flex) {
      parentData.flex = flex;
      needsLayout = true;
    }

    if (parentData.fit != fit) {
      parentData.fit = fit;
      needsLayout = true;
    }

    if (needsLayout) {
      final RenderObject? targetParent = renderObject.parent;
      if (targetParent is RenderObject) {
        targetParent.markNeedsLayout();
      }
    }
  }

  @override
  Type get debugTypicalAncestorWidgetClass => Flex;

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(IntProperty('flex', flex));
  }
}

class Expanded extends Flexible {
  const Expanded({
    super.key,
    super.flex,
    required super.child,
  }) : super(fit: FlexFit.tight);
}

class Wrap extends MultiChildRenderObjectWidget {
  const Wrap({
    super.key,
    this.direction = Axis.horizontal,
    this.alignment = WrapAlignment.start,
    this.spacing = 0.0,
    this.runAlignment = WrapAlignment.start,
    this.runSpacing = 0.0,
    this.crossAxisAlignment = WrapCrossAlignment.start,
    this.textDirection,
    this.verticalDirection = VerticalDirection.down,
    this.clipBehavior = Clip.none,
    super.children,
  });

  final Axis direction;

  final WrapAlignment alignment;

  final double spacing;

  final WrapAlignment runAlignment;

  final double runSpacing;

  final WrapCrossAlignment crossAxisAlignment;

  final TextDirection? textDirection;

  final VerticalDirection verticalDirection;

  final Clip clipBehavior;

  @override
  RenderWrap createRenderObject(BuildContext context) {
    return RenderWrap(
      direction: direction,
      alignment: alignment,
      spacing: spacing,
      runAlignment: runAlignment,
      runSpacing: runSpacing,
      crossAxisAlignment: crossAxisAlignment,
      textDirection: textDirection ?? Directionality.maybeOf(context),
      verticalDirection: verticalDirection,
      clipBehavior: clipBehavior,
    );
  }

  @override
  void updateRenderObject(BuildContext context, RenderWrap renderObject) {
    renderObject
      ..direction = direction
      ..alignment = alignment
      ..spacing = spacing
      ..runAlignment = runAlignment
      ..runSpacing = runSpacing
      ..crossAxisAlignment = crossAxisAlignment
      ..textDirection = textDirection ?? Directionality.maybeOf(context)
      ..verticalDirection = verticalDirection
      ..clipBehavior = clipBehavior;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(EnumProperty<Axis>('direction', direction));
    properties.add(EnumProperty<WrapAlignment>('alignment', alignment));
    properties.add(DoubleProperty('spacing', spacing));
    properties.add(EnumProperty<WrapAlignment>('runAlignment', runAlignment));
    properties.add(DoubleProperty('runSpacing', runSpacing));
    properties.add(EnumProperty<WrapCrossAlignment>(
        'crossAxisAlignment', crossAxisAlignment));
    properties.add(EnumProperty<TextDirection>('textDirection', textDirection,
        defaultValue: null));
    properties.add(EnumProperty<VerticalDirection>(
        'verticalDirection', verticalDirection,
        defaultValue: VerticalDirection.down));
  }
}

class Flow extends MultiChildRenderObjectWidget {
  Flow({
    super.key,
    required this.delegate,
    List<Widget> children = const <Widget>[],
    this.clipBehavior = Clip.hardEdge,
  }) : super(children: RepaintBoundary.wrapAll(children));
  // https://github.com/dart-lang/sdk/issues/29277

  const Flow.unwrapped({
    super.key,
    required this.delegate,
    super.children,
    this.clipBehavior = Clip.hardEdge,
  });

  final FlowDelegate delegate;

  final Clip clipBehavior;

  @override
  RenderFlow createRenderObject(BuildContext context) =>
      RenderFlow(delegate: delegate, clipBehavior: clipBehavior);

  @override
  void updateRenderObject(BuildContext context, RenderFlow renderObject) {
    renderObject.delegate = delegate;
    renderObject.clipBehavior = clipBehavior;
  }
}

class RichText extends MultiChildRenderObjectWidget {
  RichText({
    super.key,
    required this.text,
    this.textAlign = TextAlign.start,
    this.textDirection,
    this.softWrap = true,
    this.overflow = TextOverflow.clip,
    @Deprecated(
      'Use textScaler instead. '
      'Use of textScaleFactor was deprecated in preparation for the upcoming nonlinear text scaling support. '
      'This feature was deprecated after v3.12.0-2.0.pre.',
    )
    double textScaleFactor = 1.0,
    TextScaler textScaler = TextScaler.noScaling,
    this.maxLines,
    this.locale,
    this.strutStyle,
    this.textWidthBasis = TextWidthBasis.parent,
    this.textHeightBehavior,
    this.selectionRegistrar,
    this.selectionColor,
  })  : assert(maxLines == null || maxLines > 0),
        assert(selectionRegistrar == null || selectionColor != null),
        assert(
            textScaleFactor == 1.0 ||
                identical(textScaler, TextScaler.noScaling),
            'Use textScaler instead.'),
        textScaler = _effectiveTextScalerFrom(textScaler, textScaleFactor),
        super(
            children: WidgetSpan.extractFromInlineSpan(
                text, _effectiveTextScalerFrom(textScaler, textScaleFactor)));

  static TextScaler _effectiveTextScalerFrom(
      TextScaler textScaler, double textScaleFactor) {
    return switch ((textScaler, textScaleFactor)) {
      (final TextScaler scaler, 1.0) => scaler,
      (TextScaler.noScaling, final double textScaleFactor) =>
        TextScaler.linear(textScaleFactor),
      (final TextScaler scaler, _) => scaler,
    };
  }

  final InlineSpan text;

  final TextAlign textAlign;

  final TextDirection? textDirection;

  final bool softWrap;

  final TextOverflow overflow;

  @Deprecated(
    'Use textScaler instead. '
    'Use of textScaleFactor was deprecated in preparation for the upcoming nonlinear text scaling support. '
    'This feature was deprecated after v3.12.0-2.0.pre.',
  )
  double get textScaleFactor => textScaler.textScaleFactor;

  final TextScaler textScaler;

  final int? maxLines;

  final Locale? locale;

  final StrutStyle? strutStyle;

  final TextWidthBasis textWidthBasis;

  final ui.TextHeightBehavior? textHeightBehavior;

  final SelectionRegistrar? selectionRegistrar;

  final Color? selectionColor;

  @override
  RenderParagraph createRenderObject(BuildContext context) {
    assert(textDirection != null || debugCheckHasDirectionality(context));
    return RenderParagraph(
      text,
      textAlign: textAlign,
      textDirection: textDirection ?? Directionality.of(context),
      softWrap: softWrap,
      overflow: overflow,
      textScaler: textScaler,
      maxLines: maxLines,
      strutStyle: strutStyle,
      textWidthBasis: textWidthBasis,
      textHeightBehavior: textHeightBehavior,
      locale: locale ?? Localizations.maybeLocaleOf(context),
      registrar: selectionRegistrar,
      selectionColor: selectionColor,
    );
  }

  @override
  void updateRenderObject(BuildContext context, RenderParagraph renderObject) {
    assert(textDirection != null || debugCheckHasDirectionality(context));
    renderObject
      ..text = text
      ..textAlign = textAlign
      ..textDirection = textDirection ?? Directionality.of(context)
      ..softWrap = softWrap
      ..overflow = overflow
      ..textScaler = textScaler
      ..maxLines = maxLines
      ..strutStyle = strutStyle
      ..textWidthBasis = textWidthBasis
      ..textHeightBehavior = textHeightBehavior
      ..locale = locale ?? Localizations.maybeLocaleOf(context)
      ..registrar = selectionRegistrar
      ..selectionColor = selectionColor;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(EnumProperty<TextAlign>('textAlign', textAlign,
        defaultValue: TextAlign.start));
    properties.add(EnumProperty<TextDirection>('textDirection', textDirection,
        defaultValue: null));
    properties.add(FlagProperty('softWrap',
        value: softWrap,
        ifTrue: 'wrapping at box width',
        ifFalse: 'no wrapping except at line break characters',
        showName: true));
    properties.add(EnumProperty<TextOverflow>('overflow', overflow,
        defaultValue: TextOverflow.clip));
    properties.add(DiagnosticsProperty<TextScaler>('textScaler', textScaler,
        defaultValue: TextScaler.noScaling));
    properties.add(IntProperty('maxLines', maxLines, ifNull: 'unlimited'));
    properties.add(EnumProperty<TextWidthBasis>(
        'textWidthBasis', textWidthBasis,
        defaultValue: TextWidthBasis.parent));
    properties.add(StringProperty('text', text.toPlainText()));
    properties
        .add(DiagnosticsProperty<Locale>('locale', locale, defaultValue: null));
    properties.add(DiagnosticsProperty<StrutStyle>('strutStyle', strutStyle,
        defaultValue: null));
    properties.add(DiagnosticsProperty<TextHeightBehavior>(
        'textHeightBehavior', textHeightBehavior,
        defaultValue: null));
  }
}

class RawImage extends LeafRenderObjectWidget {
  const RawImage({
    super.key,
    this.image,
    this.debugImageLabel,
    this.width,
    this.height,
    this.scale = 1.0,
    this.color,
    this.opacity,
    this.colorBlendMode,
    this.fit,
    this.alignment = Alignment.center,
    this.repeat = ImageRepeat.noRepeat,
    this.centerSlice,
    this.matchTextDirection = false,
    this.invertColors = false,
    this.filterQuality = FilterQuality.low,
    this.isAntiAlias = false,
  });

  final ui.Image? image;

  final String? debugImageLabel;

  final double? width;

  final double? height;

  final double scale;

  final Color? color;

  final Animation<double>? opacity;

  final FilterQuality filterQuality;

  final BlendMode? colorBlendMode;

  final BoxFit? fit;

  final AlignmentGeometry alignment;

  final ImageRepeat repeat;

  final Rect? centerSlice;

  final bool matchTextDirection;

  final bool invertColors;

  final bool isAntiAlias;

  @override
  RenderImage createRenderObject(BuildContext context) {
    assert((!matchTextDirection && alignment is Alignment) ||
        debugCheckHasDirectionality(context));
    assert(
      image?.debugGetOpenHandleStackTraces()?.isNotEmpty ?? true,
      'Creator of a RawImage disposed of the image when the RawImage still '
      'needed it.',
    );
    return RenderImage(
      image: image?.clone(),
      debugImageLabel: debugImageLabel,
      width: width,
      height: height,
      scale: scale,
      color: color,
      opacity: opacity,
      colorBlendMode: colorBlendMode,
      fit: fit,
      alignment: alignment,
      repeat: repeat,
      centerSlice: centerSlice,
      matchTextDirection: matchTextDirection,
      textDirection: matchTextDirection || alignment is! Alignment
          ? Directionality.of(context)
          : null,
      invertColors: invertColors,
      isAntiAlias: isAntiAlias,
      filterQuality: filterQuality,
    );
  }

  @override
  void updateRenderObject(BuildContext context, RenderImage renderObject) {
    assert(
      image?.debugGetOpenHandleStackTraces()?.isNotEmpty ?? true,
      'Creator of a RawImage disposed of the image when the RawImage still '
      'needed it.',
    );
    renderObject
      ..image = image?.clone()
      ..debugImageLabel = debugImageLabel
      ..width = width
      ..height = height
      ..scale = scale
      ..color = color
      ..opacity = opacity
      ..colorBlendMode = colorBlendMode
      ..fit = fit
      ..alignment = alignment
      ..repeat = repeat
      ..centerSlice = centerSlice
      ..matchTextDirection = matchTextDirection
      ..textDirection = matchTextDirection || alignment is! Alignment
          ? Directionality.of(context)
          : null
      ..invertColors = invertColors
      ..isAntiAlias = isAntiAlias
      ..filterQuality = filterQuality;
  }

  @override
  void didUnmountRenderObject(RenderImage renderObject) {
    // Have the render object dispose its image handle.
    renderObject.image = null;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<ui.Image>('image', image));
    properties.add(DoubleProperty('width', width, defaultValue: null));
    properties.add(DoubleProperty('height', height, defaultValue: null));
    properties.add(DoubleProperty('scale', scale, defaultValue: 1.0));
    properties.add(ColorProperty('color', color, defaultValue: null));
    properties.add(DiagnosticsProperty<Animation<double>?>('opacity', opacity,
        defaultValue: null));
    properties.add(EnumProperty<BlendMode>('colorBlendMode', colorBlendMode,
        defaultValue: null));
    properties.add(EnumProperty<BoxFit>('fit', fit, defaultValue: null));
    properties.add(DiagnosticsProperty<AlignmentGeometry>(
        'alignment', alignment,
        defaultValue: null));
    properties.add(EnumProperty<ImageRepeat>('repeat', repeat,
        defaultValue: ImageRepeat.noRepeat));
    properties.add(DiagnosticsProperty<Rect>('centerSlice', centerSlice,
        defaultValue: null));
    properties.add(FlagProperty('matchTextDirection',
        value: matchTextDirection, ifTrue: 'match text direction'));
    properties.add(DiagnosticsProperty<bool>('invertColors', invertColors));
    properties.add(EnumProperty<FilterQuality>('filterQuality', filterQuality));
  }
}

class DefaultAssetBundle extends InheritedWidget {
  const DefaultAssetBundle({
    super.key,
    required this.bundle,
    required super.child,
  });

  final AssetBundle bundle;

  static AssetBundle of(BuildContext context) {
    final DefaultAssetBundle? result =
        context.dependOnInheritedWidgetOfExactType<DefaultAssetBundle>();
    return result?.bundle ?? rootBundle;
  }

  @override
  bool updateShouldNotify(DefaultAssetBundle oldWidget) =>
      bundle != oldWidget.bundle;
}

class WidgetToRenderBoxAdapter extends LeafRenderObjectWidget {
  WidgetToRenderBoxAdapter({
    required this.renderBox,
    this.onBuild,
    this.onUnmount,
  }) : super(key: GlobalObjectKey(renderBox));

  final RenderBox renderBox;

  final VoidCallback? onBuild;

  final VoidCallback? onUnmount;

  @override
  RenderBox createRenderObject(BuildContext context) => renderBox;

  @override
  void updateRenderObject(BuildContext context, RenderBox renderObject) {
    onBuild?.call();
  }

  @override
  void didUnmountRenderObject(RenderObject renderObject) {
    assert(renderObject == renderBox);
    onUnmount?.call();
  }
}

// EVENT HANDLING

class Listener extends SingleChildRenderObjectWidget {
  const Listener({
    super.key,
    this.onPointerDown,
    this.onPointerMove,
    this.onPointerUp,
    this.onPointerHover,
    this.onPointerCancel,
    this.onPointerPanZoomStart,
    this.onPointerPanZoomUpdate,
    this.onPointerPanZoomEnd,
    this.onPointerSignal,
    this.behavior = HitTestBehavior.deferToChild,
    super.child,
  });

  final PointerDownEventListener? onPointerDown;

  final PointerMoveEventListener? onPointerMove;

  final PointerUpEventListener? onPointerUp;

  final PointerHoverEventListener? onPointerHover;

  final PointerCancelEventListener? onPointerCancel;

  final PointerPanZoomStartEventListener? onPointerPanZoomStart;

  final PointerPanZoomUpdateEventListener? onPointerPanZoomUpdate;

  final PointerPanZoomEndEventListener? onPointerPanZoomEnd;

  final PointerSignalEventListener? onPointerSignal;

  final HitTestBehavior behavior;

  @override
  RenderPointerListener createRenderObject(BuildContext context) {
    return RenderPointerListener(
      onPointerDown: onPointerDown,
      onPointerMove: onPointerMove,
      onPointerUp: onPointerUp,
      onPointerHover: onPointerHover,
      onPointerCancel: onPointerCancel,
      onPointerPanZoomStart: onPointerPanZoomStart,
      onPointerPanZoomUpdate: onPointerPanZoomUpdate,
      onPointerPanZoomEnd: onPointerPanZoomEnd,
      onPointerSignal: onPointerSignal,
      behavior: behavior,
    );
  }

  @override
  void updateRenderObject(
      BuildContext context, RenderPointerListener renderObject) {
    renderObject
      ..onPointerDown = onPointerDown
      ..onPointerMove = onPointerMove
      ..onPointerUp = onPointerUp
      ..onPointerHover = onPointerHover
      ..onPointerCancel = onPointerCancel
      ..onPointerPanZoomStart = onPointerPanZoomStart
      ..onPointerPanZoomUpdate = onPointerPanZoomUpdate
      ..onPointerPanZoomEnd = onPointerPanZoomEnd
      ..onPointerSignal = onPointerSignal
      ..behavior = behavior;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    final List<String> listeners = <String>[
      if (onPointerDown != null) 'down',
      if (onPointerMove != null) 'move',
      if (onPointerUp != null) 'up',
      if (onPointerHover != null) 'hover',
      if (onPointerCancel != null) 'cancel',
      if (onPointerPanZoomStart != null) 'panZoomStart',
      if (onPointerPanZoomUpdate != null) 'panZoomUpdate',
      if (onPointerPanZoomEnd != null) 'panZoomEnd',
      if (onPointerSignal != null) 'signal',
    ];
    properties.add(
        IterableProperty<String>('listeners', listeners, ifEmpty: '<none>'));
    properties.add(EnumProperty<HitTestBehavior>('behavior', behavior));
  }
}

class MouseRegion extends SingleChildRenderObjectWidget {
  const MouseRegion({
    super.key,
    this.onEnter,
    this.onExit,
    this.onHover,
    this.cursor = MouseCursor.defer,
    this.opaque = true,
    this.hitTestBehavior,
    super.child,
  });

  final PointerEnterEventListener? onEnter;

  final PointerHoverEventListener? onHover;

  final PointerExitEventListener? onExit;

  final MouseCursor cursor;

  final bool opaque;

  final HitTestBehavior? hitTestBehavior;

  @override
  RenderMouseRegion createRenderObject(BuildContext context) {
    return RenderMouseRegion(
      onEnter: onEnter,
      onHover: onHover,
      onExit: onExit,
      cursor: cursor,
      opaque: opaque,
      hitTestBehavior: hitTestBehavior,
    );
  }

  @override
  void updateRenderObject(
      BuildContext context, RenderMouseRegion renderObject) {
    renderObject
      ..onEnter = onEnter
      ..onHover = onHover
      ..onExit = onExit
      ..cursor = cursor
      ..opaque = opaque
      ..hitTestBehavior = hitTestBehavior;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    final List<String> listeners = <String>[];
    if (onEnter != null) {
      listeners.add('enter');
    }
    if (onExit != null) {
      listeners.add('exit');
    }
    if (onHover != null) {
      listeners.add('hover');
    }
    properties.add(
        IterableProperty<String>('listeners', listeners, ifEmpty: '<none>'));
    properties.add(
        DiagnosticsProperty<MouseCursor>('cursor', cursor, defaultValue: null));
    properties
        .add(DiagnosticsProperty<bool>('opaque', opaque, defaultValue: true));
  }
}

class RepaintBoundary extends SingleChildRenderObjectWidget {
  const RepaintBoundary({super.key, super.child});

  factory RepaintBoundary.wrap(Widget child, int childIndex) {
    final Key key = child.key != null
        ? ValueKey<Key>(child.key!)
        : ValueKey<int>(childIndex);
    return RepaintBoundary(key: key, child: child);
  }

  static List<RepaintBoundary> wrapAll(List<Widget> widgets) =>
      <RepaintBoundary>[
        for (int i = 0; i < widgets.length; ++i)
          RepaintBoundary.wrap(widgets[i], i),
      ];

  @override
  RenderRepaintBoundary createRenderObject(BuildContext context) =>
      RenderRepaintBoundary();
}

class IgnorePointer extends SingleChildRenderObjectWidget {
  const IgnorePointer({
    super.key,
    this.ignoring = true,
    @Deprecated(
        'Use ExcludeSemantics or create a custom ignore pointer widget instead. '
        'This feature was deprecated after v3.8.0-12.0.pre.')
    this.ignoringSemantics,
    super.child,
  });

  final bool ignoring;

  @Deprecated(
      'Use ExcludeSemantics or create a custom ignore pointer widget instead. '
      'This feature was deprecated after v3.8.0-12.0.pre.')
  final bool? ignoringSemantics;

  @override
  RenderIgnorePointer createRenderObject(BuildContext context) {
    return RenderIgnorePointer(
      ignoring: ignoring,
      ignoringSemantics: ignoringSemantics,
    );
  }

  @override
  void updateRenderObject(
      BuildContext context, RenderIgnorePointer renderObject) {
    renderObject
      ..ignoring = ignoring
      ..ignoringSemantics = ignoringSemantics;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<bool>('ignoring', ignoring));
    properties.add(DiagnosticsProperty<bool>(
        'ignoringSemantics', ignoringSemantics,
        defaultValue: null));
  }
}

class AbsorbPointer extends SingleChildRenderObjectWidget {
  const AbsorbPointer({
    super.key,
    this.absorbing = true,
    @Deprecated(
        'Use ExcludeSemantics or create a custom absorb pointer widget instead. '
        'This feature was deprecated after v3.8.0-12.0.pre.')
    this.ignoringSemantics,
    super.child,
  });

  final bool absorbing;

  @Deprecated(
      'Use ExcludeSemantics or create a custom absorb pointer widget instead. '
      'This feature was deprecated after v3.8.0-12.0.pre.')
  final bool? ignoringSemantics;

  @override
  RenderAbsorbPointer createRenderObject(BuildContext context) {
    return RenderAbsorbPointer(
      absorbing: absorbing,
      ignoringSemantics: ignoringSemantics,
    );
  }

  @override
  void updateRenderObject(
      BuildContext context, RenderAbsorbPointer renderObject) {
    renderObject
      ..absorbing = absorbing
      ..ignoringSemantics = ignoringSemantics;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<bool>('absorbing', absorbing));
    properties.add(DiagnosticsProperty<bool>(
        'ignoringSemantics', ignoringSemantics,
        defaultValue: null));
  }
}

class MetaData extends SingleChildRenderObjectWidget {
  const MetaData({
    super.key,
    this.metaData,
    this.behavior = HitTestBehavior.deferToChild,
    super.child,
  });

  final dynamic metaData;

  final HitTestBehavior behavior;

  @override
  RenderMetaData createRenderObject(BuildContext context) {
    return RenderMetaData(
      metaData: metaData,
      behavior: behavior,
    );
  }

  @override
  void updateRenderObject(BuildContext context, RenderMetaData renderObject) {
    renderObject
      ..metaData = metaData
      ..behavior = behavior;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(EnumProperty<HitTestBehavior>('behavior', behavior));
    properties.add(DiagnosticsProperty<dynamic>('metaData', metaData));
  }
}

// UTILITY NODES

@immutable
class Semantics extends SingleChildRenderObjectWidget {
  Semantics({
    Key? key,
    Widget? child,
    bool container = false,
    bool explicitChildNodes = false,
    bool excludeSemantics = false,
    bool blockUserActions = false,
    bool? enabled,
    bool? checked,
    bool? mixed,
    bool? selected,
    bool? toggled,
    bool? button,
    bool? slider,
    bool? keyboardKey,
    bool? link,
    bool? header,
    bool? textField,
    bool? readOnly,
    bool? focusable,
    bool? focused,
    bool? inMutuallyExclusiveGroup,
    bool? obscured,
    bool? multiline,
    bool? scopesRoute,
    bool? namesRoute,
    bool? hidden,
    bool? image,
    bool? liveRegion,
    bool? expanded,
    int? maxValueLength,
    int? currentValueLength,
    String? label,
    AttributedString? attributedLabel,
    String? value,
    AttributedString? attributedValue,
    String? increasedValue,
    AttributedString? attributedIncreasedValue,
    String? decreasedValue,
    AttributedString? attributedDecreasedValue,
    String? hint,
    AttributedString? attributedHint,
    String? tooltip,
    String? onTapHint,
    String? onLongPressHint,
    TextDirection? textDirection,
    SemanticsSortKey? sortKey,
    SemanticsTag? tagForChildren,
    VoidCallback? onTap,
    VoidCallback? onLongPress,
    VoidCallback? onScrollLeft,
    VoidCallback? onScrollRight,
    VoidCallback? onScrollUp,
    VoidCallback? onScrollDown,
    VoidCallback? onIncrease,
    VoidCallback? onDecrease,
    VoidCallback? onCopy,
    VoidCallback? onCut,
    VoidCallback? onPaste,
    VoidCallback? onDismiss,
    MoveCursorHandler? onMoveCursorForwardByCharacter,
    MoveCursorHandler? onMoveCursorBackwardByCharacter,
    SetSelectionHandler? onSetSelection,
    SetTextHandler? onSetText,
    VoidCallback? onDidGainAccessibilityFocus,
    VoidCallback? onDidLoseAccessibilityFocus,
    Map<CustomSemanticsAction, VoidCallback>? customSemanticsActions,
  }) : this.fromProperties(
          key: key,
          child: child,
          container: container,
          explicitChildNodes: explicitChildNodes,
          excludeSemantics: excludeSemantics,
          blockUserActions: blockUserActions,
          properties: SemanticsProperties(
            enabled: enabled,
            checked: checked,
            mixed: mixed,
            expanded: expanded,
            toggled: toggled,
            selected: selected,
            button: button,
            slider: slider,
            keyboardKey: keyboardKey,
            link: link,
            header: header,
            textField: textField,
            readOnly: readOnly,
            focusable: focusable,
            focused: focused,
            inMutuallyExclusiveGroup: inMutuallyExclusiveGroup,
            obscured: obscured,
            multiline: multiline,
            scopesRoute: scopesRoute,
            namesRoute: namesRoute,
            hidden: hidden,
            image: image,
            liveRegion: liveRegion,
            maxValueLength: maxValueLength,
            currentValueLength: currentValueLength,
            label: label,
            attributedLabel: attributedLabel,
            value: value,
            attributedValue: attributedValue,
            increasedValue: increasedValue,
            attributedIncreasedValue: attributedIncreasedValue,
            decreasedValue: decreasedValue,
            attributedDecreasedValue: attributedDecreasedValue,
            hint: hint,
            attributedHint: attributedHint,
            tooltip: tooltip,
            textDirection: textDirection,
            sortKey: sortKey,
            tagForChildren: tagForChildren,
            onTap: onTap,
            onLongPress: onLongPress,
            onScrollLeft: onScrollLeft,
            onScrollRight: onScrollRight,
            onScrollUp: onScrollUp,
            onScrollDown: onScrollDown,
            onIncrease: onIncrease,
            onDecrease: onDecrease,
            onCopy: onCopy,
            onCut: onCut,
            onPaste: onPaste,
            onMoveCursorForwardByCharacter: onMoveCursorForwardByCharacter,
            onMoveCursorBackwardByCharacter: onMoveCursorBackwardByCharacter,
            onDidGainAccessibilityFocus: onDidGainAccessibilityFocus,
            onDidLoseAccessibilityFocus: onDidLoseAccessibilityFocus,
            onDismiss: onDismiss,
            onSetSelection: onSetSelection,
            onSetText: onSetText,
            customSemanticsActions: customSemanticsActions,
            hintOverrides: onTapHint != null || onLongPressHint != null
                ? SemanticsHintOverrides(
                    onTapHint: onTapHint,
                    onLongPressHint: onLongPressHint,
                  )
                : null,
          ),
        );

  const Semantics.fromProperties({
    super.key,
    super.child,
    this.container = false,
    this.explicitChildNodes = false,
    this.excludeSemantics = false,
    this.blockUserActions = false,
    required this.properties,
  });

  final SemanticsProperties properties;

  final bool container;

  final bool explicitChildNodes;

  final bool excludeSemantics;

  final bool blockUserActions;

  @override
  RenderSemanticsAnnotations createRenderObject(BuildContext context) {
    return RenderSemanticsAnnotations(
      container: container,
      explicitChildNodes: explicitChildNodes,
      excludeSemantics: excludeSemantics,
      blockUserActions: blockUserActions,
      properties: properties,
      textDirection: _getTextDirection(context),
    );
  }

  TextDirection? _getTextDirection(BuildContext context) {
    if (properties.textDirection != null) {
      return properties.textDirection;
    }

    final bool containsText = properties.attributedLabel != null ||
        properties.label != null ||
        properties.value != null ||
        properties.hint != null ||
        properties.tooltip != null;

    if (!containsText) {
      return null;
    }

    return Directionality.maybeOf(context);
  }

  @override
  void updateRenderObject(
      BuildContext context, RenderSemanticsAnnotations renderObject) {
    renderObject
      ..container = container
      ..explicitChildNodes = explicitChildNodes
      ..excludeSemantics = excludeSemantics
      ..blockUserActions = blockUserActions
      ..properties = properties
      ..textDirection = _getTextDirection(context);
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<bool>('container', container));
    properties.add(DiagnosticsProperty<SemanticsProperties>(
        'properties', this.properties));
    this.properties.debugFillProperties(properties);
  }
}

class MergeSemantics extends SingleChildRenderObjectWidget {
  const MergeSemantics({super.key, super.child});

  @override
  RenderMergeSemantics createRenderObject(BuildContext context) =>
      RenderMergeSemantics();
}

class BlockSemantics extends SingleChildRenderObjectWidget {
  const BlockSemantics({super.key, this.blocking = true, super.child});

  final bool blocking;

  @override
  RenderBlockSemantics createRenderObject(BuildContext context) =>
      RenderBlockSemantics(blocking: blocking);

  @override
  void updateRenderObject(
      BuildContext context, RenderBlockSemantics renderObject) {
    renderObject.blocking = blocking;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<bool>('blocking', blocking));
  }
}

class ExcludeSemantics extends SingleChildRenderObjectWidget {
  const ExcludeSemantics({
    super.key,
    this.excluding = true,
    super.child,
  });

  final bool excluding;

  @override
  RenderExcludeSemantics createRenderObject(BuildContext context) =>
      RenderExcludeSemantics(excluding: excluding);

  @override
  void updateRenderObject(
      BuildContext context, RenderExcludeSemantics renderObject) {
    renderObject.excluding = excluding;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<bool>('excluding', excluding));
  }
}

class IndexedSemantics extends SingleChildRenderObjectWidget {
  const IndexedSemantics({
    super.key,
    required this.index,
    super.child,
  });

  final int index;

  @override
  RenderIndexedSemantics createRenderObject(BuildContext context) =>
      RenderIndexedSemantics(index: index);

  @override
  void updateRenderObject(
      BuildContext context, RenderIndexedSemantics renderObject) {
    renderObject.index = index;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<int>('index', index));
  }
}

class KeyedSubtree extends StatelessWidget {
  const KeyedSubtree({
    super.key,
    required this.child,
  });

  factory KeyedSubtree.wrap(Widget child, int childIndex) {
    final Key key = child.key != null
        ? ValueKey<Key>(child.key!)
        : ValueKey<int>(childIndex);
    return KeyedSubtree(key: key, child: child);
  }

  final Widget child;

  static List<Widget> ensureUniqueKeysForList(List<Widget> items,
      {int baseIndex = 0}) {
    if (items.isEmpty) {
      return items;
    }

    final List<Widget> itemsWithUniqueKeys = <Widget>[];
    int itemIndex = baseIndex;
    for (final Widget item in items) {
      itemsWithUniqueKeys.add(KeyedSubtree.wrap(item, itemIndex));
      itemIndex += 1;
    }

    assert(!debugItemsHaveDuplicateKeys(itemsWithUniqueKeys));
    return itemsWithUniqueKeys;
  }

  @override
  Widget build(BuildContext context) => child;
}

class Builder extends StatelessWidget {
  const Builder({
    super.key,
    required this.builder,
  });

  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) => builder(context);
}

typedef StatefulWidgetBuilder = Widget Function(
    BuildContext context, StateSetter setState);

class StatefulBuilder extends StatefulWidget {
  const StatefulBuilder({
    super.key,
    required this.builder,
  });

  final StatefulWidgetBuilder builder;

  @override
  State<StatefulBuilder> createState() => _StatefulBuilderState();
}

class _StatefulBuilderState extends State<StatefulBuilder> {
  @override
  Widget build(BuildContext context) => widget.builder(context, setState);
}

class ColoredBox extends SingleChildRenderObjectWidget {
  const ColoredBox({required this.color, super.child, super.key});

  final Color color;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderColoredBox(color: color);
  }

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderColoredBox).color = color;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<Color>('color', color));
  }
}

class _RenderColoredBox extends RenderProxyBoxWithHitTestBehavior {
  _RenderColoredBox({required Color color})
      : _color = color,
        super(behavior: HitTestBehavior.opaque);

  Color get color => _color;
  Color _color;
  set color(Color value) {
    if (value == _color) {
      return;
    }
    _color = value;
    markNeedsPaint();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    // It's tempting to want to optimize out this `drawRect()` call if the
    // color is transparent (alpha==0), but doing so would be incorrect. See
    // https://github.com/flutter/flutter/pull/72526#issuecomment-749185938 for
    // a good description of why.
    if (size > Size.zero) {
      context.canvas.drawRect(offset & size, Paint()..color = color);
    }
    if (child != null) {
      context.paintChild(child!, offset);
    }
  }
}
