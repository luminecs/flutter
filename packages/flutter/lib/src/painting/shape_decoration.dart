
import 'package:flutter/foundation.dart';

import 'basic_types.dart';
import 'borders.dart';
import 'box_border.dart';
import 'box_decoration.dart';
import 'box_shadow.dart';
import 'circle_border.dart';
import 'colors.dart';
import 'decoration.dart';
import 'decoration_image.dart';
import 'edge_insets.dart';
import 'gradient.dart';
import 'image_provider.dart';
import 'rounded_rectangle_border.dart';

class ShapeDecoration extends Decoration {
  const ShapeDecoration({
    this.color,
    this.image,
    this.gradient,
    this.shadows,
    required this.shape,
  }) : assert(!(color != null && gradient != null));

  factory ShapeDecoration.fromBoxDecoration(BoxDecoration source) {
    final ShapeBorder shape;
    switch (source.shape) {
      case BoxShape.circle:
        if (source.border != null) {
          assert(source.border!.isUniform);
          shape = CircleBorder(side: source.border!.top);
        } else {
          shape = const CircleBorder();
        }
      case BoxShape.rectangle:
        if (source.borderRadius != null) {
          assert(source.border == null || source.border!.isUniform);
          shape = RoundedRectangleBorder(
            side: source.border?.top ?? BorderSide.none,
            borderRadius: source.borderRadius!,
          );
        } else {
          shape = source.border ?? const Border();
        }
    }
    return ShapeDecoration(
      color: source.color,
      image: source.image,
      gradient: source.gradient,
      shadows: source.boxShadow,
      shape: shape,
    );
  }

  @override
  Path getClipPath(Rect rect, TextDirection textDirection) {
    return shape.getOuterPath(rect, textDirection: textDirection);
  }

  final Color? color;

  final Gradient? gradient;

  final DecorationImage? image;

  final List<BoxShadow>? shadows;

  final ShapeBorder shape;

  @override
  EdgeInsetsGeometry get padding => shape.dimensions;

  @override
  bool get isComplex => shadows != null;

  @override
  ShapeDecoration? lerpFrom(Decoration? a, double t) {
    if (a is BoxDecoration) {
      return ShapeDecoration.lerp(ShapeDecoration.fromBoxDecoration(a), this, t);
    } else if (a == null || a is ShapeDecoration) {
      return ShapeDecoration.lerp(a as ShapeDecoration?, this, t);
    }
    return super.lerpFrom(a, t) as ShapeDecoration?;
  }

  @override
  ShapeDecoration? lerpTo(Decoration? b, double t) {
    if (b is BoxDecoration) {
      return ShapeDecoration.lerp(this, ShapeDecoration.fromBoxDecoration(b), t);
    } else if (b == null || b is ShapeDecoration) {
      return ShapeDecoration.lerp(this, b as ShapeDecoration?, t);
    }
    return super.lerpTo(b, t) as ShapeDecoration?;
  }

  static ShapeDecoration? lerp(ShapeDecoration? a, ShapeDecoration? b, double t) {
    if (identical(a, b)) {
      return a;
    }
    if (a != null && b != null) {
      if (t == 0.0) {
        return a;
      }
      if (t == 1.0) {
        return b;
      }
    }
    return ShapeDecoration(
      color: Color.lerp(a?.color, b?.color, t),
      gradient: Gradient.lerp(a?.gradient, b?.gradient, t),
      image: DecorationImage.lerp(a?.image, b?.image, t),
      shadows: BoxShadow.lerpList(a?.shadows, b?.shadows, t),
      shape: ShapeBorder.lerp(a?.shape, b?.shape, t)!,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is ShapeDecoration
        && other.color == color
        && other.gradient == gradient
        && other.image == image
        && listEquals<BoxShadow>(other.shadows, shadows)
        && other.shape == shape;
  }

  @override
  int get hashCode => Object.hash(
    color,
    gradient,
    image,
    shape,
    shadows == null ? null : Object.hashAll(shadows!),
  );

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.defaultDiagnosticsTreeStyle = DiagnosticsTreeStyle.whitespace;
    properties.add(ColorProperty('color', color, defaultValue: null));
    properties.add(DiagnosticsProperty<Gradient>('gradient', gradient, defaultValue: null));
    properties.add(DiagnosticsProperty<DecorationImage>('image', image, defaultValue: null));
    properties.add(IterableProperty<BoxShadow>('shadows', shadows, defaultValue: null, style: DiagnosticsTreeStyle.whitespace));
    properties.add(DiagnosticsProperty<ShapeBorder>('shape', shape));
  }

  @override
  bool hitTest(Size size, Offset position, { TextDirection? textDirection }) {
    return shape.getOuterPath(Offset.zero & size, textDirection: textDirection).contains(position);
  }

  @override
  BoxPainter createBoxPainter([ VoidCallback? onChanged ]) {
    assert(onChanged != null || image == null);
    return _ShapeDecorationPainter(this, onChanged!);
  }
}

class _ShapeDecorationPainter extends BoxPainter {
  _ShapeDecorationPainter(this._decoration, VoidCallback onChanged)
    : super(onChanged);

  final ShapeDecoration _decoration;

  Rect? _lastRect;
  TextDirection? _lastTextDirection;
  late Path _outerPath;
  Path? _innerPath;
  Paint? _interiorPaint;
  int? _shadowCount;
  late List<Rect> _shadowBounds;
  late List<Path> _shadowPaths;
  late List<Paint> _shadowPaints;

  @override
  VoidCallback get onChanged => super.onChanged!;

  void _precache(Rect rect, TextDirection? textDirection) {
    if (rect == _lastRect && textDirection == _lastTextDirection) {
      return;
    }

    // We reach here in two cases:
    //  - the very first time we paint, in which case everything except _decoration is null
    //  - subsequent times, if the rect has changed, in which case we only need to update
    //    the features that depend on the actual rect.
    if (_interiorPaint == null && (_decoration.color != null || _decoration.gradient != null)) {
      _interiorPaint = Paint();
      if (_decoration.color != null) {
        _interiorPaint!.color = _decoration.color!;
      }
    }
    if (_decoration.gradient != null) {
      _interiorPaint!.shader = _decoration.gradient!.createShader(rect, textDirection: textDirection);
    }
    if (_decoration.shadows != null) {
      if (_shadowCount == null) {
        _shadowCount = _decoration.shadows!.length;
        _shadowPaints = <Paint>[
          ..._decoration.shadows!.map((BoxShadow shadow) => shadow.toPaint()),
        ];
      }
      if (_decoration.shape.preferPaintInterior) {
        _shadowBounds = <Rect>[
          ..._decoration.shadows!.map((BoxShadow shadow) {
            return rect.shift(shadow.offset).inflate(shadow.spreadRadius);
          }),
        ];
      } else {
        _shadowPaths = <Path>[
          ..._decoration.shadows!.map((BoxShadow shadow) {
            return _decoration.shape.getOuterPath(rect.shift(shadow.offset).inflate(shadow.spreadRadius), textDirection: textDirection);
          }),
        ];
      }
    }
    if (!_decoration.shape.preferPaintInterior && (_interiorPaint != null || _shadowCount != null)) {
      _outerPath = _decoration.shape.getOuterPath(rect, textDirection: textDirection);
    }
    if (_decoration.image != null) {
      _innerPath = _decoration.shape.getInnerPath(rect, textDirection: textDirection);
    }

    _lastRect = rect;
    _lastTextDirection = textDirection;
  }

  void _paintShadows(Canvas canvas, Rect rect, TextDirection? textDirection) {
    if (_shadowCount != null) {
      if (_decoration.shape.preferPaintInterior) {
        for (int index = 0; index < _shadowCount!; index += 1) {
          _decoration.shape.paintInterior(canvas, _shadowBounds[index], _shadowPaints[index], textDirection: textDirection);
        }
      } else {
        for (int index = 0; index < _shadowCount!; index += 1) {
          canvas.drawPath(_shadowPaths[index], _shadowPaints[index]);
        }
      }
    }
  }

  void _paintInterior(Canvas canvas, Rect rect, TextDirection? textDirection) {
    if (_interiorPaint != null) {
      if (_decoration.shape.preferPaintInterior) {
        _decoration.shape.paintInterior(canvas, rect, _interiorPaint!, textDirection: textDirection);
      } else {
        canvas.drawPath(_outerPath, _interiorPaint!);
      }
    }
  }

  DecorationImagePainter? _imagePainter;
  void _paintImage(Canvas canvas, ImageConfiguration configuration) {
    if (_decoration.image == null) {
      return;
    }
    _imagePainter ??= _decoration.image!.createPainter(onChanged);
    _imagePainter!.paint(canvas, _lastRect!, _innerPath, configuration);
  }

  @override
  void dispose() {
    _imagePainter?.dispose();
    super.dispose();
  }

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    assert(configuration.size != null);
    final Rect rect = offset & configuration.size!;
    final TextDirection? textDirection = configuration.textDirection;
    _precache(rect, textDirection);
    _paintShadows(canvas, rect, textDirection);
    _paintInterior(canvas, rect, textDirection);
    _paintImage(canvas, configuration);
    _decoration.shape.paint(canvas, rect, textDirection: textDirection);
  }
}