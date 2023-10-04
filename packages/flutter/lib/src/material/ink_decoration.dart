import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'debug.dart';
import 'material.dart';

class Ink extends StatefulWidget {
  Ink({
    super.key,
    this.padding,
    Color? color,
    Decoration? decoration,
    this.width,
    this.height,
    this.child,
  })  : assert(padding == null || padding.isNonNegative),
        assert(decoration == null || decoration.debugAssertIsValid()),
        assert(
          color == null || decoration == null,
          'Cannot provide both a color and a decoration\n'
          'The color argument is just a shorthand for "decoration: BoxDecoration(color: color)".',
        ),
        decoration =
            decoration ?? (color != null ? BoxDecoration(color: color) : null);

  Ink.image({
    super.key,
    this.padding,
    required ImageProvider image,
    ImageErrorListener? onImageError,
    ColorFilter? colorFilter,
    BoxFit? fit,
    AlignmentGeometry alignment = Alignment.center,
    Rect? centerSlice,
    ImageRepeat repeat = ImageRepeat.noRepeat,
    bool matchTextDirection = false,
    this.width,
    this.height,
    this.child,
  })  : assert(padding == null || padding.isNonNegative),
        decoration = BoxDecoration(
          image: DecorationImage(
            image: image,
            onError: onImageError,
            colorFilter: colorFilter,
            fit: fit,
            alignment: alignment,
            centerSlice: centerSlice,
            repeat: repeat,
            matchTextDirection: matchTextDirection,
          ),
        );

  final Widget? child;

  final EdgeInsetsGeometry? padding;

  final Decoration? decoration;

  final double? width;

  final double? height;

  EdgeInsetsGeometry get _paddingIncludingDecoration {
    if (decoration == null) {
      return padding ?? EdgeInsets.zero;
    }
    final EdgeInsetsGeometry decorationPadding = decoration!.padding;
    if (padding == null) {
      return decorationPadding;
    }
    return padding!.add(decorationPadding);
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<EdgeInsetsGeometry>('padding', padding,
        defaultValue: null));
    properties.add(
        DiagnosticsProperty<Decoration>('bg', decoration, defaultValue: null));
  }

  @override
  State<Ink> createState() => _InkState();
}

class _InkState extends State<Ink> {
  final GlobalKey _boxKey = GlobalKey();
  InkDecoration? _ink;

  void _handleRemoved() {
    _ink = null;
  }

  @override
  void deactivate() {
    _ink?.dispose();
    assert(_ink == null);
    super.deactivate();
  }

  Widget _build(BuildContext context) {
    // By creating the InkDecoration from within a Builder widget, we can
    // use the RenderBox of the Padding widget.
    if (_ink == null) {
      _ink = InkDecoration(
        decoration: widget.decoration,
        isVisible: Visibility.of(context),
        configuration: createLocalImageConfiguration(context),
        controller: Material.of(context),
        referenceBox: _boxKey.currentContext!.findRenderObject()! as RenderBox,
        onRemoved: _handleRemoved,
      );
    } else {
      _ink!.decoration = widget.decoration;
      _ink!.isVisible = Visibility.of(context);
      _ink!.configuration = createLocalImageConfiguration(context);
    }
    return widget.child ??
        ConstrainedBox(constraints: const BoxConstraints.expand());
  }

  @override
  Widget build(BuildContext context) {
    assert(debugCheckHasMaterial(context));
    Widget result = Padding(
      key: _boxKey,
      padding: widget._paddingIncludingDecoration,
      child: Builder(builder: _build),
    );
    if (widget.width != null || widget.height != null) {
      result = SizedBox(
        width: widget.width,
        height: widget.height,
        child: result,
      );
    }
    return result;
  }
}

class InkDecoration extends InkFeature {
  InkDecoration({
    required Decoration? decoration,
    bool isVisible = true,
    required ImageConfiguration configuration,
    required super.controller,
    required super.referenceBox,
    super.onRemoved,
  }) : _configuration = configuration {
    this.decoration = decoration;
    this.isVisible = isVisible;
    controller.addInkFeature(this);
  }

  BoxPainter? _painter;

  Decoration? get decoration => _decoration;
  Decoration? _decoration;
  set decoration(Decoration? value) {
    if (value == _decoration) {
      return;
    }
    _decoration = value;
    _painter?.dispose();
    _painter = _decoration?.createBoxPainter(_handleChanged);
    controller.markNeedsPaint();
  }

  bool get isVisible => _isVisible;
  bool _isVisible = true;
  set isVisible(bool value) {
    if (value == _isVisible) {
      return;
    }
    _isVisible = value;
    controller.markNeedsPaint();
  }

  ImageConfiguration get configuration => _configuration;
  ImageConfiguration _configuration;
  set configuration(ImageConfiguration value) {
    if (value == _configuration) {
      return;
    }
    _configuration = value;
    controller.markNeedsPaint();
  }

  void _handleChanged() {
    controller.markNeedsPaint();
  }

  @override
  void dispose() {
    _painter?.dispose();
    super.dispose();
  }

  @override
  void paintFeature(Canvas canvas, Matrix4 transform) {
    if (_painter == null || !isVisible) {
      return;
    }
    final Offset? originOffset = MatrixUtils.getAsTranslation(transform);
    final ImageConfiguration sizedConfiguration = configuration.copyWith(
      size: referenceBox.size,
    );
    if (originOffset == null) {
      canvas.save();
      canvas.transform(transform.storage);
      _painter!.paint(canvas, Offset.zero, sizedConfiguration);
      canvas.restore();
    } else {
      _painter!.paint(canvas, originOffset, sizedConfiguration);
    }
  }
}
