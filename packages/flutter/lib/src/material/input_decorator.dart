// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'color_scheme.dart';
import 'colors.dart';
import 'constants.dart';
import 'icon_button.dart';
import 'icon_button_theme.dart';
import 'input_border.dart';
import 'material.dart';
import 'material_state.dart';
import 'text_theme.dart';
import 'theme.dart';
import 'theme_data.dart';

// Examples can assume:
// late Widget _myIcon;

// The duration value extracted from:
// https://github.com/material-components/material-components-android/blob/master/lib/java/com/google/android/material/textfield/TextInputLayout.java
const Duration _kTransitionDuration = Duration(milliseconds: 167);
const Curve _kTransitionCurve = Curves.fastOutSlowIn;
const double _kFinalLabelScale = 0.75;

// The default duration for hint fade in/out transitions.
//
// Animating hint is not mentioned in the Material specification.
// The animation is kept for backard compatibility and a short duration
// is used to mitigate the UX impact.
const Duration _kHintFadeTransitionDuration = Duration(milliseconds: 20);

// Defines the gap in the InputDecorator's outline border where the
// floating label will appear.
class _InputBorderGap extends ChangeNotifier {
  double? _start;
  double? get start => _start;
  set start(double? value) {
    if (value != _start) {
      _start = value;
      notifyListeners();
    }
  }

  double _extent = 0.0;
  double get extent => _extent;
  set extent(double value) {
    if (value != _extent) {
      _extent = value;
      notifyListeners();
    }
  }

  @override
  // ignore: avoid_equals_and_hash_code_on_mutable_classes, this class is not used in collection
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is _InputBorderGap
        && other.start == start
        && other.extent == extent;
  }

  @override
  // ignore: avoid_equals_and_hash_code_on_mutable_classes, this class is not used in collection
  int get hashCode => Object.hash(start, extent);

  @override
  String toString() => describeIdentity(this);
}

// Used to interpolate between two InputBorders.
class _InputBorderTween extends Tween<InputBorder> {
  _InputBorderTween({super.begin, super.end});

  @override
  InputBorder lerp(double t) => ShapeBorder.lerp(begin, end, t)! as InputBorder;
}

// Passes the _InputBorderGap parameters along to an InputBorder's paint method.
class _InputBorderPainter extends CustomPainter {
  _InputBorderPainter({
    required Listenable repaint,
    required this.borderAnimation,
    required this.border,
    required this.gapAnimation,
    required this.gap,
    required this.textDirection,
    required this.fillColor,
    required this.hoverAnimation,
    required this.hoverColorTween,
  }) : super(repaint: repaint);

  final Animation<double> borderAnimation;
  final _InputBorderTween border;
  final Animation<double> gapAnimation;
  final _InputBorderGap gap;
  final TextDirection textDirection;
  final Color fillColor;
  final ColorTween hoverColorTween;
  final Animation<double> hoverAnimation;

  Color get blendedColor => Color.alphaBlend(hoverColorTween.evaluate(hoverAnimation)!, fillColor);

  @override
  void paint(Canvas canvas, Size size) {
    final InputBorder borderValue = border.evaluate(borderAnimation);
    final Rect canvasRect = Offset.zero & size;
    final Color blendedFillColor = blendedColor;
    if (blendedFillColor.alpha > 0) {
      canvas.drawPath(
        borderValue.getOuterPath(canvasRect, textDirection: textDirection),
        Paint()
          ..color = blendedFillColor
          ..style = PaintingStyle.fill,
      );
    }

    borderValue.paint(
      canvas,
      canvasRect,
      gapStart: gap.start,
      gapExtent: gap.extent,
      gapPercentage: gapAnimation.value,
      textDirection: textDirection,
    );
  }

  @override
  bool shouldRepaint(_InputBorderPainter oldPainter) {
    return borderAnimation != oldPainter.borderAnimation
        || hoverAnimation != oldPainter.hoverAnimation
        || gapAnimation != oldPainter.gapAnimation
        || border != oldPainter.border
        || gap != oldPainter.gap
        || textDirection != oldPainter.textDirection;
  }

  @override
  String toString() => describeIdentity(this);
}

// An analog of AnimatedContainer, which can animate its shaped border, for
// _InputBorder. This specialized animated container is needed because the
// _InputBorderGap, which is computed at layout time, is required by the
// _InputBorder's paint method.
class _BorderContainer extends StatefulWidget {
  const _BorderContainer({
    required this.border,
    required this.gap,
    required this.gapAnimation,
    required this.fillColor,
    required this.hoverColor,
    required this.isHovering,
  });

  final InputBorder border;
  final _InputBorderGap gap;
  final Animation<double> gapAnimation;
  final Color fillColor;
  final Color hoverColor;
  final bool isHovering;

  @override
  _BorderContainerState createState() => _BorderContainerState();
}

class _BorderContainerState extends State<_BorderContainer> with TickerProviderStateMixin {
  static const Duration _kHoverDuration = Duration(milliseconds: 15);

  late AnimationController _controller;
  late AnimationController _hoverColorController;
  late Animation<double> _borderAnimation;
  late _InputBorderTween _border;
  late Animation<double> _hoverAnimation;
  late ColorTween _hoverColorTween;

  @override
  void initState() {
    super.initState();
    _hoverColorController = AnimationController(
      duration: _kHoverDuration,
      value: widget.isHovering ? 1.0 : 0.0,
      vsync: this,
    );
    _controller = AnimationController(
      duration: _kTransitionDuration,
      vsync: this,
    );
    _borderAnimation = CurvedAnimation(
      parent: _controller,
      curve: _kTransitionCurve,
      reverseCurve: _kTransitionCurve.flipped,
    );
    _border = _InputBorderTween(
      begin: widget.border,
      end: widget.border,
    );
    _hoverAnimation = CurvedAnimation(
      parent: _hoverColorController,
      curve: Curves.linear,
    );
    _hoverColorTween = ColorTween(begin: Colors.transparent, end: widget.hoverColor);
  }

  @override
  void dispose() {
    _controller.dispose();
    _hoverColorController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_BorderContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.border != oldWidget.border) {
      _border = _InputBorderTween(
        begin: oldWidget.border,
        end: widget.border,
      );
      _controller
        ..value = 0.0
        ..forward();
    }
    if (widget.hoverColor != oldWidget.hoverColor) {
      _hoverColorTween = ColorTween(begin: Colors.transparent, end: widget.hoverColor);
    }
    if (widget.isHovering != oldWidget.isHovering) {
      if (widget.isHovering) {
        _hoverColorController.forward();
      } else {
        _hoverColorController.reverse();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: _InputBorderPainter(
        repaint: Listenable.merge(<Listenable>[
          _borderAnimation,
          widget.gap,
          _hoverColorController,
        ]),
        borderAnimation: _borderAnimation,
        border: _border,
        gapAnimation: widget.gapAnimation,
        gap: widget.gap,
        textDirection: Directionality.of(context),
        fillColor: widget.fillColor,
        hoverColorTween: _hoverColorTween,
        hoverAnimation: _hoverAnimation,
      ),
    );
  }
}

// Used to "shake" the floating label to the left and right
// when the errorText first appears.
class _Shaker extends AnimatedWidget {
  const _Shaker({
    required Animation<double> animation,
    this.child,
  }) : super(listenable: animation);

  final Widget? child;

  Animation<double> get animation => listenable as Animation<double>;

  double get translateX {
    const double shakeDelta = 4.0;
    final double t = animation.value;
    if (t <= 0.25) {
      return -t * shakeDelta;
    } else if (t < 0.75) {
      return (t - 0.5) * shakeDelta;
    } else {
      return (1.0 - t) * 4.0 * shakeDelta;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Transform(
      transform: Matrix4.translationValues(translateX, 0.0, 0.0),
      child: child,
    );
  }
}

// Display the helper and error text. When the error text appears
// it fades and the helper text fades out. The error text also
// slides upwards a little when it first appears.
class _HelperError extends StatefulWidget {
  const _HelperError({
    this.textAlign,
    this.helperText,
    this.helperStyle,
    this.helperMaxLines,
    this.error,
    this.errorText,
    this.errorStyle,
    this.errorMaxLines,
  });

  final TextAlign? textAlign;
  final String? helperText;
  final TextStyle? helperStyle;
  final int? helperMaxLines;
  final Widget? error;
  final String? errorText;
  final TextStyle? errorStyle;
  final int? errorMaxLines;

  @override
  _HelperErrorState createState() => _HelperErrorState();
}

class _HelperErrorState extends State<_HelperError> with SingleTickerProviderStateMixin {
  // If the height of this widget and the counter are zero ("empty") at
  // layout time, no space is allocated for the subtext.
  static const Widget empty = SizedBox.shrink();

  late AnimationController _controller;
  Widget? _helper;
  Widget? _error;

  bool get _hasError => widget.errorText != null || widget.error != null;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: _kTransitionDuration,
      vsync: this,
    );
    if (_hasError) {
      _error = _buildError();
      _controller.value = 1.0;
    } else if (widget.helperText != null) {
      _helper = _buildHelper();
    }
    _controller.addListener(_handleChange);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleChange() {
    setState(() {
      // The _controller's value has changed.
    });
  }

  @override
  void didUpdateWidget(_HelperError old) {
    super.didUpdateWidget(old);

    final Widget? newError = widget.error;
    final String? newErrorText = widget.errorText;
    final String? newHelperText = widget.helperText;
    final Widget? oldError = old.error;
    final String? oldErrorText = old.errorText;
    final String? oldHelperText = old.helperText;

    final bool errorStateChanged = (newError != null) != (oldError != null);
    final bool errorTextStateChanged = (newErrorText != null) != (oldErrorText != null);
    final bool helperTextStateChanged = newErrorText == null && (newHelperText != null) != (oldHelperText != null);

    if (errorStateChanged || errorTextStateChanged || helperTextStateChanged) {
      if (newError != null || newErrorText != null) {
        _error = _buildError();
        _controller.forward();
      } else if (newHelperText != null) {
        _helper = _buildHelper();
        _controller.reverse();
      } else {
        _controller.reverse();
      }
    }
  }

  Widget _buildHelper() {
    assert(widget.helperText != null);
    return Semantics(
      container: true,
      child: FadeTransition(
        opacity: Tween<double>(begin: 1.0, end: 0.0).animate(_controller),
        child: Text(
          widget.helperText!,
          style: widget.helperStyle,
          textAlign: widget.textAlign,
          overflow: TextOverflow.ellipsis,
          maxLines: widget.helperMaxLines,
        ),
      ),
    );
  }

  Widget _buildError() {
    assert(widget.error != null || widget.errorText != null);
    return Semantics(
      container: true,
      child: FadeTransition(
        opacity: _controller,
        child: FractionalTranslation(
          translation: Tween<Offset>(
            begin: const Offset(0.0, -0.25),
            end: Offset.zero,
          ).evaluate(_controller.view),
          child: widget.error ?? Text(
            widget.errorText!,
            style: widget.errorStyle,
            textAlign: widget.textAlign,
            overflow: TextOverflow.ellipsis,
            maxLines: widget.errorMaxLines,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_controller.isDismissed) {
      _error = null;
      if (widget.helperText != null) {
        return _helper = _buildHelper();
      } else {
        _helper = null;
        return empty;
      }
    }

    if (_controller.isCompleted) {
      _helper = null;
      if (_hasError) {
        return _error = _buildError();
      } else {
        _error = null;
        return empty;
      }
    }

    if (_helper == null && _hasError) {
      return _buildError();
    }

    if (_error == null && widget.helperText != null) {
      return _buildHelper();
    }

    if (_hasError) {
      return Stack(
        children: <Widget>[
          FadeTransition(
            opacity: Tween<double>(begin: 1.0, end: 0.0).animate(_controller),
            child: _helper,
          ),
          _buildError(),
        ],
      );
    }

    if (widget.helperText != null) {
      return Stack(
        children: <Widget>[
          _buildHelper(),
          FadeTransition(
            opacity: _controller,
            child: _error,
          ),
        ],
      );
    }

    return empty;
  }
}

enum FloatingLabelBehavior {
  never,
  auto,
  always,
}

@immutable
class FloatingLabelAlignment {
  const FloatingLabelAlignment._(this._x) : assert(_x >= -1.0 && _x <= 1.0);

  // -1 denotes start, 0 denotes center, and 1 denotes end.
  final double _x;

  static const FloatingLabelAlignment start = FloatingLabelAlignment._(-1.0);
  static const FloatingLabelAlignment center = FloatingLabelAlignment._(0.0);

  @override
  int get hashCode => _x.hashCode;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is FloatingLabelAlignment
            && _x == other._x;
  }

  static String _stringify(double x) {
    if (x == -1.0) {
      return 'FloatingLabelAlignment.start';
    }
    if (x == 0.0) {
      return 'FloatingLabelAlignment.center';
    }
    return 'FloatingLabelAlignment(x: ${x.toStringAsFixed(1)})';
  }

  @override
  String toString() => _stringify(_x);
}

// Identifies the children of a _RenderDecorationElement.
enum _DecorationSlot {
  icon,
  input,
  label,
  hint,
  prefix,
  suffix,
  prefixIcon,
  suffixIcon,
  helperError,
  counter,
  container,
}

// An analog of InputDecoration for the _Decorator widget.
@immutable
class _Decoration {
  const _Decoration({
    required this.contentPadding,
    required this.isCollapsed,
    required this.floatingLabelHeight,
    required this.floatingLabelProgress,
    required this.floatingLabelAlignment,
    required this.border,
    required this.borderGap,
    required this.alignLabelWithHint,
    required this.isDense,
    required this.visualDensity,
    this.icon,
    this.input,
    this.label,
    this.hint,
    this.prefix,
    this.suffix,
    this.prefixIcon,
    this.suffixIcon,
    this.helperError,
    this.counter,
    this.container,
  });

  final EdgeInsetsGeometry contentPadding;
  final bool isCollapsed;
  final double floatingLabelHeight;
  final double floatingLabelProgress;
  final FloatingLabelAlignment floatingLabelAlignment;
  final InputBorder border;
  final _InputBorderGap borderGap;
  final bool alignLabelWithHint;
  final bool? isDense;
  final VisualDensity visualDensity;
  final Widget? icon;
  final Widget? input;
  final Widget? label;
  final Widget? hint;
  final Widget? prefix;
  final Widget? suffix;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final Widget? helperError;
  final Widget? counter;
  final Widget? container;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is _Decoration
        && other.contentPadding == contentPadding
        && other.isCollapsed == isCollapsed
        && other.floatingLabelHeight == floatingLabelHeight
        && other.floatingLabelProgress == floatingLabelProgress
        && other.floatingLabelAlignment == floatingLabelAlignment
        && other.border == border
        && other.borderGap == borderGap
        && other.alignLabelWithHint == alignLabelWithHint
        && other.isDense == isDense
        && other.visualDensity == visualDensity
        && other.icon == icon
        && other.input == input
        && other.label == label
        && other.hint == hint
        && other.prefix == prefix
        && other.suffix == suffix
        && other.prefixIcon == prefixIcon
        && other.suffixIcon == suffixIcon
        && other.helperError == helperError
        && other.counter == counter
        && other.container == container;
  }

  @override
  int get hashCode => Object.hash(
    contentPadding,
    floatingLabelHeight,
    floatingLabelProgress,
    floatingLabelAlignment,
    border,
    borderGap,
    alignLabelWithHint,
    isDense,
    visualDensity,
    icon,
    input,
    label,
    hint,
    prefix,
    suffix,
    prefixIcon,
    suffixIcon,
    helperError,
    counter,
    container,
  );
}

// A container for the layout values computed by _RenderDecoration._layout.
// These values are used by _RenderDecoration.performLayout to position
// all of the renderer children of a _RenderDecoration.
class _RenderDecorationLayout {
  const _RenderDecorationLayout({
    required this.boxToBaseline,
    required this.inputBaseline, // for InputBorderType.underline
    required this.outlineBaseline, // for InputBorderType.outline
    required this.subtextBaseline,
    required this.containerHeight,
    required this.subtextHeight,
  });

  final Map<RenderBox?, double> boxToBaseline;
  final double inputBaseline;
  final double outlineBaseline;
  final double subtextBaseline; // helper/error counter
  final double containerHeight;
  final double subtextHeight;
}

// The workhorse: layout and paint a _Decorator widget's _Decoration.
class _RenderDecoration extends RenderBox with SlottedContainerRenderObjectMixin<_DecorationSlot, RenderBox> {
  _RenderDecoration({
    required _Decoration decoration,
    required TextDirection textDirection,
    required TextBaseline textBaseline,
    required bool isFocused,
    required bool expands,
    required bool material3,
    TextAlignVertical? textAlignVertical,
  }) : _decoration = decoration,
       _textDirection = textDirection,
       _textBaseline = textBaseline,
       _textAlignVertical = textAlignVertical,
       _isFocused = isFocused,
       _expands = expands,
       _material3 = material3;

  static const double subtextGap = 8.0;

  RenderBox? get icon => childForSlot(_DecorationSlot.icon);
  RenderBox? get input => childForSlot(_DecorationSlot.input);
  RenderBox? get label => childForSlot(_DecorationSlot.label);
  RenderBox? get hint => childForSlot(_DecorationSlot.hint);
  RenderBox? get prefix => childForSlot(_DecorationSlot.prefix);
  RenderBox? get suffix => childForSlot(_DecorationSlot.suffix);
  RenderBox? get prefixIcon => childForSlot(_DecorationSlot.prefixIcon);
  RenderBox? get suffixIcon => childForSlot(_DecorationSlot.suffixIcon);
  RenderBox? get helperError => childForSlot(_DecorationSlot.helperError);
  RenderBox? get counter => childForSlot(_DecorationSlot.counter);
  RenderBox? get container => childForSlot(_DecorationSlot.container);

  // The returned list is ordered for hit testing.
  @override
  Iterable<RenderBox> get children {
    return <RenderBox>[
      if (icon != null)
        icon!,
      if (input != null)
        input!,
      if (prefixIcon != null)
        prefixIcon!,
      if (suffixIcon != null)
        suffixIcon!,
      if (prefix != null)
        prefix!,
      if (suffix != null)
        suffix!,
      if (label != null)
        label!,
      if (hint != null)
        hint!,
      if (helperError != null)
        helperError!,
      if (counter != null)
        counter!,
      if (container != null)
        container!,
    ];
  }

  _Decoration get decoration => _decoration;
  _Decoration _decoration;
  set decoration(_Decoration value) {
    if (_decoration == value) {
      return;
    }
    _decoration = value;
    markNeedsLayout();
  }

  TextDirection get textDirection => _textDirection;
  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (_textDirection == value) {
      return;
    }
    _textDirection = value;
    markNeedsLayout();
  }

  TextBaseline get textBaseline => _textBaseline;
  TextBaseline _textBaseline;
  set textBaseline(TextBaseline value) {
    if (_textBaseline == value) {
      return;
    }
    _textBaseline = value;
    markNeedsLayout();
  }

  TextAlignVertical get _defaultTextAlignVertical => _isOutlineAligned
      ? TextAlignVertical.center
      : TextAlignVertical.top;
  TextAlignVertical get textAlignVertical => _textAlignVertical ?? _defaultTextAlignVertical;
  TextAlignVertical? _textAlignVertical;
  set textAlignVertical(TextAlignVertical? value) {
    if (_textAlignVertical == value) {
      return;
    }
    // No need to relayout if the effective value is still the same.
    if (textAlignVertical.y == (value?.y ?? _defaultTextAlignVertical.y)) {
      _textAlignVertical = value;
      return;
    }
    _textAlignVertical = value;
    markNeedsLayout();
  }

  bool get isFocused => _isFocused;
  bool _isFocused;
  set isFocused(bool value) {
    if (_isFocused == value) {
      return;
    }
    _isFocused = value;
    markNeedsSemanticsUpdate();
  }

  bool get expands => _expands;
  bool _expands = false;
  set expands(bool value) {
    if (_expands == value) {
      return;
    }
    _expands = value;
    markNeedsLayout();
  }

  bool get material3 => _material3;
  bool _material3 = false;
  set material3(bool value) {
    if (_material3 == value) {
      return;
    }
    _material3 = value;
    markNeedsLayout();
  }

  // Indicates that the decoration should be aligned to accommodate an outline
  // border.
  bool get _isOutlineAligned {
    return !decoration.isCollapsed && decoration.border.isOutline;
  }

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    if (icon != null) {
      visitor(icon!);
    }
    if (prefix != null) {
      visitor(prefix!);
    }
    if (prefixIcon != null) {
      visitor(prefixIcon!);
    }

    if (label != null) {
      visitor(label!);
    }
    if (hint != null) {
      if (isFocused) {
        visitor(hint!);
      } else if (label == null) {
        visitor(hint!);
      }
    }

    if (input != null) {
      visitor(input!);
    }
    if (suffixIcon != null) {
      visitor(suffixIcon!);
    }
    if (suffix != null) {
      visitor(suffix!);
    }
    if (container != null) {
      visitor(container!);
    }
    if (helperError != null) {
      visitor(helperError!);
    }
    if (counter != null) {
      visitor(counter!);
    }
  }

  @override
  bool get sizedByParent => false;

  static double _minWidth(RenderBox? box, double height) {
    return box == null ? 0.0 : box.getMinIntrinsicWidth(height);
  }

  static double _maxWidth(RenderBox? box, double height) {
    return box == null ? 0.0 : box.getMaxIntrinsicWidth(height);
  }

  static double _minHeight(RenderBox? box, double width) {
    return box == null ? 0.0 : box.getMinIntrinsicHeight(width);
  }

  static Size _boxSize(RenderBox? box) => box == null ? Size.zero : box.size;

  static BoxParentData _boxParentData(RenderBox box) => box.parentData! as BoxParentData;

  EdgeInsets get contentPadding => decoration.contentPadding as EdgeInsets;

  // Lay out the given box if needed, and return its baseline.
  double _layoutLineBox(RenderBox? box, BoxConstraints constraints) {
    if (box == null) {
      return 0.0;
    }
    box.layout(constraints, parentUsesSize: true);
    // Since internally, all layout is performed against the alphabetic baseline,
    // (eg, ascents/descents are all relative to alphabetic, even if the font is
    // an ideographic or hanging font), we should always obtain the reference
    // baseline from the alphabetic baseline. The ideographic baseline is for
    // use post-layout and is derived from the alphabetic baseline combined with
    // the font metrics.
    final double baseline = box.getDistanceToBaseline(TextBaseline.alphabetic)!;

    assert(() {
      if (baseline >= 0) {
        return true;
      }
      throw FlutterError.fromParts(<DiagnosticsNode>[
        ErrorSummary("One of InputDecorator's children reported a negative baseline offset."),
        ErrorDescription(
          '${box.runtimeType}, of size ${box.size}, reported a negative '
          'alphabetic baseline of $baseline.',
        ),
      ]);
    }());
    return baseline;
  }

  // Returns a value used by performLayout to position all of the renderers.
  // This method applies layout to all of the renderers except the container.
  // For convenience, the container is laid out in performLayout().
  _RenderDecorationLayout _layout(BoxConstraints layoutConstraints) {
    assert(
      layoutConstraints.maxWidth < double.infinity,
      'An InputDecorator, which is typically created by a TextField, cannot '
      'have an unbounded width.\n'
      'This happens when the parent widget does not provide a finite width '
      'constraint. For example, if the InputDecorator is contained by a Row, '
      'then its width must be constrained. An Expanded widget or a SizedBox '
      'can be used to constrain the width of the InputDecorator or the '
      'TextField that contains it.',
    );

    // Margin on each side of subtext (counter and helperError)
    final Map<RenderBox?, double> boxToBaseline = <RenderBox?, double>{};
    final BoxConstraints boxConstraints = layoutConstraints.loosen();

    // Layout all the widgets used by InputDecorator
    boxToBaseline[icon] = _layoutLineBox(icon, boxConstraints);
    final BoxConstraints containerConstraints = boxConstraints.copyWith(
      maxWidth: boxConstraints.maxWidth - _boxSize(icon).width,
    );
    boxToBaseline[prefixIcon] = _layoutLineBox(prefixIcon, containerConstraints);
    boxToBaseline[suffixIcon] = _layoutLineBox(suffixIcon, containerConstraints);
    final BoxConstraints contentConstraints = containerConstraints.copyWith(
      maxWidth: math.max(0.0, containerConstraints.maxWidth - contentPadding.horizontal),
    );
    boxToBaseline[prefix] = _layoutLineBox(prefix, contentConstraints);
    boxToBaseline[suffix] = _layoutLineBox(suffix, contentConstraints);

    final double inputWidth = math.max(
      0.0,
      constraints.maxWidth - (
        _boxSize(icon).width
        + (prefixIcon != null ? 0 : (textDirection == TextDirection.ltr ? contentPadding.left : contentPadding.right))
        + _boxSize(prefixIcon).width
        + _boxSize(prefix).width
        + _boxSize(suffix).width
        + _boxSize(suffixIcon).width
        + (suffixIcon != null ? 0 : (textDirection == TextDirection.ltr ? contentPadding.right : contentPadding.left))),
    );
    // Increase the available width for the label when it is scaled down.
    final double invertedLabelScale = lerpDouble(1.00, 1 / _kFinalLabelScale, decoration.floatingLabelProgress)!;
    double suffixIconWidth = _boxSize(suffixIcon).width;
    if (decoration.border.isOutline) {
      suffixIconWidth = lerpDouble(suffixIconWidth, 0.0, decoration.floatingLabelProgress)!;
    }
    final double labelWidth = math.max(
      0.0,
      constraints.maxWidth - (
        _boxSize(icon).width
        + contentPadding.left
        + _boxSize(prefixIcon).width
        + suffixIconWidth
        + contentPadding.right),
    );
    boxToBaseline[label] = _layoutLineBox(
      label,
      boxConstraints.copyWith(maxWidth: labelWidth * invertedLabelScale),
    );
    boxToBaseline[hint] = _layoutLineBox(
      hint,
      boxConstraints.copyWith(minWidth: inputWidth, maxWidth: inputWidth),
    );
    boxToBaseline[counter] = _layoutLineBox(counter, contentConstraints);

    // The helper or error text can occupy the full width less the space
    // occupied by the icon and counter.
    boxToBaseline[helperError] = _layoutLineBox(
      helperError,
      contentConstraints.copyWith(
        maxWidth: math.max(0.0, contentConstraints.maxWidth - _boxSize(counter).width),
      ),
    );

    // The height of the input needs to accommodate label above and counter and
    // helperError below, when they exist.
    final double labelHeight = label == null
      ? 0
      : decoration.floatingLabelHeight;
    final double topHeight = decoration.border.isOutline
      ? math.max(labelHeight - boxToBaseline[label]!, 0)
      : labelHeight;
    final double counterHeight = counter == null
      ? 0
      : boxToBaseline[counter]! + subtextGap;
    final bool helperErrorExists = helperError?.size != null
        && helperError!.size.height > 0;
    final double helperErrorHeight = !helperErrorExists
      ? 0
      : helperError!.size.height + subtextGap;
    final double bottomHeight = math.max(
      counterHeight,
      helperErrorHeight,
    );
    final Offset densityOffset = decoration.visualDensity.baseSizeAdjustment;
    boxToBaseline[input] = _layoutLineBox(
      input,
      boxConstraints.deflate(EdgeInsets.only(
        top: contentPadding.top + topHeight + densityOffset.dy / 2,
        bottom: contentPadding.bottom + bottomHeight + densityOffset.dy / 2,
      )).copyWith(
        minWidth: inputWidth,
        maxWidth: inputWidth,
      ),
    );

    // The field can be occupied by a hint or by the input itself
    final double hintHeight = hint?.size.height ?? 0;
    final double inputDirectHeight = input?.size.height ?? 0;
    final double inputHeight = math.max(hintHeight, inputDirectHeight);
    final double inputInternalBaseline = math.max(
      boxToBaseline[input]!,
      boxToBaseline[hint]!,
    );

    // Calculate the amount that prefix/suffix affects height above and below
    // the input.
    final double prefixHeight = prefix?.size.height ?? 0;
    final double suffixHeight = suffix?.size.height ?? 0;
    final double fixHeight = math.max(
      boxToBaseline[prefix]!,
      boxToBaseline[suffix]!,
    );
    final double fixAboveInput = math.max(0, fixHeight - inputInternalBaseline);
    final double fixBelowBaseline = math.max(
      prefixHeight - boxToBaseline[prefix]!,
      suffixHeight - boxToBaseline[suffix]!,
    );
    // TODO(justinmc): fixBelowInput should have no effect when there is no
    // prefix/suffix below the input.
    // https://github.com/flutter/flutter/issues/66050
    final double fixBelowInput = math.max(
      0,
      fixBelowBaseline - (inputHeight - inputInternalBaseline),
    );

    // Calculate the height of the input text container.
    final double prefixIconHeight = prefixIcon?.size.height ?? 0;
    final double suffixIconHeight = suffixIcon?.size.height ?? 0;
    final double fixIconHeight = math.max(prefixIconHeight, suffixIconHeight);
    final double contentHeight = math.max(
      fixIconHeight,
      topHeight
      + contentPadding.top
      + fixAboveInput
      + inputHeight
      + fixBelowInput
      + contentPadding.bottom
      + densityOffset.dy,
    );
    final double minContainerHeight = decoration.isDense! || decoration.isCollapsed || expands
      ? 0.0
      : kMinInteractiveDimension;
    final double maxContainerHeight = math.max(0.0, boxConstraints.maxHeight - bottomHeight);
    final double containerHeight = expands
      ? maxContainerHeight
      : math.min(math.max(contentHeight, minContainerHeight), maxContainerHeight);

    // Ensure the text is vertically centered in cases where the content is
    // shorter than kMinInteractiveDimension.
    final double interactiveAdjustment = minContainerHeight > contentHeight
      ? (minContainerHeight - contentHeight) / 2.0
      : 0.0;

    // Try to consider the prefix/suffix as part of the text when aligning it.
    // If the prefix/suffix overflows however, allow it to extend outside of the
    // input and align the remaining part of the text and prefix/suffix.
    final double overflow = math.max(0, contentHeight - maxContainerHeight);
    // Map textAlignVertical from -1:1 to 0:1 so that it can be used to scale
    // the baseline from its minimum to maximum values.
    final double textAlignVerticalFactor = (textAlignVertical.y + 1.0) / 2.0;
    // Adjust to try to fit top overflow inside the input on an inverse scale of
    // textAlignVertical, so that top aligned text adjusts the most and bottom
    // aligned text doesn't adjust at all.
    final double baselineAdjustment = fixAboveInput - overflow * (1 - textAlignVerticalFactor);

    // The baselines that will be used to draw the actual input text content.
    final double topInputBaseline = contentPadding.top
      + topHeight
      + inputInternalBaseline
      + baselineAdjustment
      + interactiveAdjustment
      + densityOffset.dy / 2.0;
    final double maxContentHeight = containerHeight - contentPadding.vertical - topHeight - densityOffset.dy;
    final double alignableHeight = fixAboveInput + inputHeight + fixBelowInput;
    final double maxVerticalOffset = maxContentHeight - alignableHeight;
    final double textAlignVerticalOffset = maxVerticalOffset * textAlignVerticalFactor;
    final double inputBaseline = topInputBaseline + textAlignVerticalOffset;

    // The three main alignments for the baseline when an outline is present are
    //
    //  * top (-1.0): topmost point considering padding.
    //  * center (0.0): the absolute center of the input ignoring padding but
    //      accommodating the border and floating label.
    //  * bottom (1.0): bottommost point considering padding.
    //
    // That means that if the padding is uneven, center is not the exact
    // midpoint of top and bottom. To account for this, the above center and
    // below center alignments are interpolated independently.
    final double outlineCenterBaseline = inputInternalBaseline
      + baselineAdjustment / 2.0
      + (containerHeight - (2.0 + inputHeight)) / 2.0;
    final double outlineTopBaseline = topInputBaseline;
    final double outlineBottomBaseline = topInputBaseline + maxVerticalOffset;
    final double outlineBaseline = _interpolateThree(
      outlineTopBaseline,
      outlineCenterBaseline,
      outlineBottomBaseline,
      textAlignVertical,
    );

    // Find the positions of the text below the input when it exists.
    double subtextCounterBaseline = 0;
    double subtextHelperBaseline = 0;
    double subtextCounterHeight = 0;
    double subtextHelperHeight = 0;
    if (counter != null) {
      subtextCounterBaseline =
        containerHeight + subtextGap + boxToBaseline[counter]!;
      subtextCounterHeight = counter!.size.height + subtextGap;
    }
    if (helperErrorExists) {
      subtextHelperBaseline =
        containerHeight + subtextGap + boxToBaseline[helperError]!;
      subtextHelperHeight = helperErrorHeight;
    }
    final double subtextBaseline = math.max(
      subtextCounterBaseline,
      subtextHelperBaseline,
    );
    final double subtextHeight = math.max(
      subtextCounterHeight,
      subtextHelperHeight,
    );

    return _RenderDecorationLayout(
      boxToBaseline: boxToBaseline,
      containerHeight: containerHeight,
      inputBaseline: inputBaseline,
      outlineBaseline: outlineBaseline,
      subtextBaseline: subtextBaseline,
      subtextHeight: subtextHeight,
    );
  }

  // Interpolate between three stops using textAlignVertical. This is used to
  // calculate the outline baseline, which ignores padding when the alignment is
  // middle. When the alignment is less than zero, it interpolates between the
  // centered text box's top and the top of the content padding. When the
  // alignment is greater than zero, it interpolates between the centered box's
  // top and the position that would align the bottom of the box with the bottom
  // padding.
  double _interpolateThree(double begin, double middle, double end, TextAlignVertical textAlignVertical) {
    if (textAlignVertical.y <= 0) {
      // It's possible for begin, middle, and end to not be in order because of
      // excessive padding. Those cases are handled by using middle.
      if (begin >= middle) {
        return middle;
      }
      // Do a standard linear interpolation on the first half, between begin and
      // middle.
      final double t = textAlignVertical.y + 1;
      return begin + (middle - begin) * t;
    }

    if (middle >= end) {
      return middle;
    }
    // Do a standard linear interpolation on the second half, between middle and
    // end.
    final double t = textAlignVertical.y;
    return middle + (end - middle) * t;
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    return _minWidth(icon, height)
      + contentPadding.left
      + _minWidth(prefixIcon, height)
      + _minWidth(prefix, height)
      + math.max(_minWidth(input, height), _minWidth(hint, height))
      + _minWidth(suffix, height)
      + _minWidth(suffixIcon, height)
      + contentPadding.right;
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    return _maxWidth(icon, height)
      + contentPadding.left
      + _maxWidth(prefixIcon, height)
      + _maxWidth(prefix, height)
      + math.max(_maxWidth(input, height), _maxWidth(hint, height))
      + _maxWidth(suffix, height)
      + _maxWidth(suffixIcon, height)
      + contentPadding.right;
  }

  double _lineHeight(double width, List<RenderBox?> boxes) {
    double height = 0.0;
    for (final RenderBox? box in boxes) {
      if (box == null) {
        continue;
      }
      height = math.max(_minHeight(box, width), height);
    }
    return height;
    // TODO(hansmuller): this should compute the overall line height for the
    // boxes when they've been baseline-aligned.
    // See https://github.com/flutter/flutter/issues/13715
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    final double iconHeight = _minHeight(icon, width);
    final double iconWidth = _minWidth(icon, iconHeight);

    width = math.max(width - iconWidth, 0.0);

    final double prefixIconHeight = _minHeight(prefixIcon, width);
    final double prefixIconWidth = _minWidth(prefixIcon, prefixIconHeight);

    final double suffixIconHeight = _minHeight(suffixIcon, width);
    final double suffixIconWidth = _minWidth(suffixIcon, suffixIconHeight);

    width = math.max(width - contentPadding.horizontal, 0.0);

    final double counterHeight = _minHeight(counter, width);
    final double counterWidth = _minWidth(counter, counterHeight);

    final double helperErrorAvailableWidth = math.max(width - counterWidth, 0.0);
    final double helperErrorHeight = _minHeight(helperError, helperErrorAvailableWidth);
    double subtextHeight = math.max(counterHeight, helperErrorHeight);
    if (subtextHeight > 0.0) {
      subtextHeight += subtextGap;
    }

    final double prefixHeight = _minHeight(prefix, width);
    final double prefixWidth = _minWidth(prefix, prefixHeight);

    final double suffixHeight = _minHeight(suffix, width);
    final double suffixWidth = _minWidth(suffix, suffixHeight);

    final double availableInputWidth = math.max(width - prefixWidth - suffixWidth - prefixIconWidth - suffixIconWidth, 0.0);
    final double inputHeight = _lineHeight(availableInputWidth, <RenderBox?>[input, hint]);
    final double inputMaxHeight = <double>[inputHeight, prefixHeight, suffixHeight].reduce(math.max);

    final Offset densityOffset = decoration.visualDensity.baseSizeAdjustment;
    final double contentHeight = contentPadding.top
      + (label == null ? 0.0 : decoration.floatingLabelHeight)
      + inputMaxHeight
      + contentPadding.bottom
      + densityOffset.dy;
    final double containerHeight = <double>[iconHeight, contentHeight, prefixIconHeight, suffixIconHeight].reduce(math.max);
    final double minContainerHeight = decoration.isDense! || expands
      ? 0.0
      : kMinInteractiveDimension;
    return math.max(containerHeight, minContainerHeight) + subtextHeight;
  }

  @override
  double computeMaxIntrinsicHeight(double width) {
    return computeMinIntrinsicHeight(width);
  }

  @override
  double computeDistanceToActualBaseline(TextBaseline baseline) {
    return _boxParentData(input!).offset.dy + (input?.computeDistanceToActualBaseline(baseline) ?? 0.0);
  }

  // Records where the label was painted.
  Matrix4? _labelTransform;

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    assert(debugCannotComputeDryLayout(
      reason: 'Layout requires baseline metrics, which are only available after a full layout.',
    ));
    return Size.zero;
  }

  ChildSemanticsConfigurationsResult _childSemanticsConfigurationDelegate(List<SemanticsConfiguration> childConfigs) {
    final ChildSemanticsConfigurationsResultBuilder builder = ChildSemanticsConfigurationsResultBuilder();
    List<SemanticsConfiguration>? prefixMergeGroup;
    List<SemanticsConfiguration>? suffixMergeGroup;
    for (final SemanticsConfiguration childConfig in childConfigs) {
      if (childConfig.tagsChildrenWith(_InputDecoratorState._kPrefixSemanticsTag)) {
        prefixMergeGroup ??= <SemanticsConfiguration>[];
        prefixMergeGroup.add(childConfig);
      } else if (childConfig.tagsChildrenWith(_InputDecoratorState._kSuffixSemanticsTag)) {
        suffixMergeGroup ??= <SemanticsConfiguration>[];
        suffixMergeGroup.add(childConfig);
      } else {
        builder.markAsMergeUp(childConfig);
      }
    }
    if (prefixMergeGroup != null) {
      builder.markAsSiblingMergeGroup(prefixMergeGroup);
    }
    if (suffixMergeGroup != null) {
      builder.markAsSiblingMergeGroup(suffixMergeGroup);
    }
    return builder.build();
  }

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    config.childConfigurationsDelegate = _childSemanticsConfigurationDelegate;
  }

  @override
  void performLayout() {
    final BoxConstraints constraints = this.constraints;
    _labelTransform = null;
    final _RenderDecorationLayout layout = _layout(constraints);

    final double overallWidth = constraints.maxWidth;
    final double overallHeight = layout.containerHeight + layout.subtextHeight;

    final RenderBox? container = this.container;
    if (container != null) {
      final BoxConstraints containerConstraints = BoxConstraints.tightFor(
        height: layout.containerHeight,
        width: overallWidth - _boxSize(icon).width,
      );
      container.layout(containerConstraints, parentUsesSize: true);
      final double x;
      switch (textDirection) {
        case TextDirection.rtl:
          x = 0.0;
        case TextDirection.ltr:
          x = _boxSize(icon).width;
       }
      _boxParentData(container).offset = Offset(x, 0.0);
    }

    late double height;
    double centerLayout(RenderBox box, double x) {
      _boxParentData(box).offset = Offset(x, (height - box.size.height) / 2.0);
      return box.size.width;
    }

    late double baseline;
    double baselineLayout(RenderBox box, double x) {
      _boxParentData(box).offset = Offset(x, baseline - layout.boxToBaseline[box]!);
      return box.size.width;
    }

    final double left = contentPadding.left;
    final double right = overallWidth - contentPadding.right;

    height = layout.containerHeight;
    baseline = _isOutlineAligned ? layout.outlineBaseline : layout.inputBaseline;

    if (icon != null) {
      final double x;
      switch (textDirection) {
        case TextDirection.rtl:
          x = overallWidth - icon!.size.width;
        case TextDirection.ltr:
          x = 0.0;
       }
      centerLayout(icon!, x);
    }

    switch (textDirection) {
      case TextDirection.rtl: {
        double start = right - _boxSize(icon).width;
        double end = left;
        if (prefixIcon != null) {
          start += contentPadding.right;
          start -= centerLayout(prefixIcon!, start - prefixIcon!.size.width);
        }
        if (label != null) {
          if (decoration.alignLabelWithHint) {
            baselineLayout(label!, start - label!.size.width);
          } else {
            centerLayout(label!, start - label!.size.width);
          }
        }
        if (prefix != null) {
          start -= baselineLayout(prefix!, start - prefix!.size.width);
        }
        if (input != null) {
          baselineLayout(input!, start - input!.size.width);
        }
        if (hint != null) {
          baselineLayout(hint!, start - hint!.size.width);
        }
        if (suffixIcon != null) {
          end -= contentPadding.left;
          end += centerLayout(suffixIcon!, end);
        }
        if (suffix != null) {
          end += baselineLayout(suffix!, end);
        }
        break;
      }
      case TextDirection.ltr: {
        double start = left + _boxSize(icon).width;
        double end = right;
        if (prefixIcon != null) {
          start -= contentPadding.left;
          start += centerLayout(prefixIcon!, start);
        }
        if (label != null) {
          if (decoration.alignLabelWithHint) {
            baselineLayout(label!, start);
          } else {
            centerLayout(label!, start);
          }
        }
        if (prefix != null) {
          start += baselineLayout(prefix!, start);
        }
        if (input != null) {
          baselineLayout(input!, start);
        }
        if (hint != null) {
          baselineLayout(hint!, start);
        }
        if (suffixIcon != null) {
          end += contentPadding.right;
          end -= centerLayout(suffixIcon!, end - suffixIcon!.size.width);
        }
        if (suffix != null) {
          end -= baselineLayout(suffix!, end - suffix!.size.width);
        }
        break;
      }
    }

    if (helperError != null || counter != null) {
      height = layout.subtextHeight;
      baseline = layout.subtextBaseline;

      switch (textDirection) {
        case TextDirection.rtl:
          if (helperError != null) {
            baselineLayout(helperError!, right - helperError!.size.width - _boxSize(icon).width);
          }
          if (counter != null) {
            baselineLayout(counter!, left);
          }
        case TextDirection.ltr:
          if (helperError != null) {
            baselineLayout(helperError!, left + _boxSize(icon).width);
          }
          if (counter != null) {
            baselineLayout(counter!, right - counter!.size.width);
          }
      }
    }

    if (label != null) {
      final double labelX = _boxParentData(label!).offset.dx;
      // +1 shifts the range of x from (-1.0, 1.0) to (0.0, 2.0).
      final double floatAlign = decoration.floatingLabelAlignment._x + 1;
      final double floatWidth = _boxSize(label).width * _kFinalLabelScale;
      // When floating label is centered, its x is relative to
      // _BorderContainer's x and is independent of label's x.
      switch (textDirection) {
        case TextDirection.rtl:
          double offsetToPrefixIcon = 0.0;
          if (prefixIcon != null && !decoration.alignLabelWithHint) {
            offsetToPrefixIcon = material3 ? _boxSize(prefixIcon).width - left : 0;
          }
          decoration.borderGap.start = lerpDouble(labelX + _boxSize(label).width + offsetToPrefixIcon,
            _boxSize(container).width / 2.0 + floatWidth / 2.0,
            floatAlign);

        case TextDirection.ltr:
          // The value of _InputBorderGap.start is relative to the origin of the
          // _BorderContainer which is inset by the icon's width. Although, when
          // floating label is centered, it's already relative to _BorderContainer.
          double offsetToPrefixIcon = 0.0;
          if (prefixIcon != null && !decoration.alignLabelWithHint) {
            offsetToPrefixIcon = material3 ? (-_boxSize(prefixIcon).width + left) : 0;
          }
          decoration.borderGap.start = lerpDouble(labelX - _boxSize(icon).width + offsetToPrefixIcon,
            _boxSize(container).width / 2.0 - floatWidth / 2.0,
            floatAlign);
      }
      decoration.borderGap.extent = label!.size.width * _kFinalLabelScale;
    } else {
      decoration.borderGap.start = null;
      decoration.borderGap.extent = 0.0;
    }

    size = constraints.constrain(Size(overallWidth, overallHeight));
    assert(size.width == constraints.constrainWidth(overallWidth));
    assert(size.height == constraints.constrainHeight(overallHeight));
  }

  void _paintLabel(PaintingContext context, Offset offset) {
    context.paintChild(label!, offset);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    void doPaint(RenderBox? child) {
      if (child != null) {
        context.paintChild(child, _boxParentData(child).offset + offset);
      }
    }
    doPaint(container);

    if (label != null) {
      final Offset labelOffset = _boxParentData(label!).offset;
      final double labelHeight = _boxSize(label).height;
      final double labelWidth = _boxSize(label).width;
      // +1 shifts the range of x from (-1.0, 1.0) to (0.0, 2.0).
      final double floatAlign = decoration.floatingLabelAlignment._x + 1;
      final double floatWidth = labelWidth * _kFinalLabelScale;
      final double borderWeight = decoration.border.borderSide.width;
      final double t = decoration.floatingLabelProgress;
      // The center of the outline border label ends up a little below the
      // center of the top border line.
      final bool isOutlineBorder = decoration.border.isOutline;
      // Temporary opt-in fix for https://github.com/flutter/flutter/issues/54028
      // Center the scaled label relative to the border.
      final double floatingY = isOutlineBorder ? (-labelHeight * _kFinalLabelScale) / 2.0 + borderWeight / 2.0 : contentPadding.top;
      final double scale = lerpDouble(1.0, _kFinalLabelScale, t)!;
      final double centeredFloatX = _boxParentData(container!).offset.dx +
          _boxSize(container).width / 2.0 - floatWidth / 2.0;
      final double startX;
      double floatStartX;
      switch (textDirection) {
        case TextDirection.rtl: // origin is on the right
          startX = labelOffset.dx + labelWidth * (1.0 - scale);
          floatStartX = startX;
          if (prefixIcon != null && !decoration.alignLabelWithHint && isOutlineBorder) {
            floatStartX += material3 ? _boxSize(prefixIcon).width - contentPadding.left : 0.0;
          }
        case TextDirection.ltr: // origin on the left
          startX = labelOffset.dx;
          floatStartX = startX;
          if (prefixIcon != null && !decoration.alignLabelWithHint && isOutlineBorder) {
            floatStartX += material3 ? -_boxSize(prefixIcon).width + contentPadding.left : 0.0;
          }
      }
      final double floatEndX = lerpDouble(floatStartX, centeredFloatX, floatAlign)!;
      final double dx = lerpDouble(startX, floatEndX, t)!;
      final double dy = lerpDouble(0.0, floatingY - labelOffset.dy, t)!;
      _labelTransform = Matrix4.identity()
        ..translate(dx, labelOffset.dy + dy)
        ..scale(scale);
      layer = context.pushTransform(
        needsCompositing,
        offset,
        _labelTransform!,
        _paintLabel,
        oldLayer: layer as TransformLayer?,
      );
    } else {
      layer = null;
    }

    doPaint(icon);
    doPaint(prefix);
    doPaint(suffix);
    doPaint(prefixIcon);
    doPaint(suffixIcon);
    doPaint(hint);
    doPaint(input);
    doPaint(helperError);
    doPaint(counter);
  }

  @override
  bool hitTestSelf(Offset position) => true;

  @override
  bool hitTestChildren(BoxHitTestResult result, { required Offset position }) {
    for (final RenderBox child in children) {
      // The label must be handled specially since we've transformed it.
      final Offset offset = _boxParentData(child).offset;
      final bool isHit = result.addWithPaintOffset(
        offset: offset,
        position: position,
        hitTest: (BoxHitTestResult result, Offset transformed) {
          assert(transformed == position - offset);
          return child.hitTest(result, position: transformed);
        },
      );
      if (isHit) {
        return true;
      }
    }
    return false;
  }

  @override
  void applyPaintTransform(RenderObject child, Matrix4 transform) {
    if (child == label && _labelTransform != null) {
      final Offset labelOffset = _boxParentData(label!).offset;
      transform
        ..multiply(_labelTransform!)
        ..translate(-labelOffset.dx, -labelOffset.dy);
    }
    super.applyPaintTransform(child, transform);
  }
}

class _Decorator extends SlottedMultiChildRenderObjectWidget<_DecorationSlot, RenderBox> {
  const _Decorator({
    required this.textAlignVertical,
    required this.decoration,
    required this.textDirection,
    required this.textBaseline,
    required this.isFocused,
    required this.expands,
  });

  final _Decoration decoration;
  final TextDirection textDirection;
  final TextBaseline textBaseline;
  final TextAlignVertical? textAlignVertical;
  final bool isFocused;
  final bool expands;

  @override
  Iterable<_DecorationSlot> get slots => _DecorationSlot.values;

  @override
  Widget? childForSlot(_DecorationSlot slot) {
    switch (slot) {
      case _DecorationSlot.icon:
        return decoration.icon;
      case _DecorationSlot.input:
        return decoration.input;
      case _DecorationSlot.label:
        return decoration.label;
      case _DecorationSlot.hint:
        return decoration.hint;
      case _DecorationSlot.prefix:
        return decoration.prefix;
      case _DecorationSlot.suffix:
        return decoration.suffix;
      case _DecorationSlot.prefixIcon:
        return decoration.prefixIcon;
      case _DecorationSlot.suffixIcon:
        return decoration.suffixIcon;
      case _DecorationSlot.helperError:
        return decoration.helperError;
      case _DecorationSlot.counter:
        return decoration.counter;
      case _DecorationSlot.container:
        return decoration.container;
    }
  }

  @override
  _RenderDecoration createRenderObject(BuildContext context) {
    return _RenderDecoration(
      decoration: decoration,
      textDirection: textDirection,
      textBaseline: textBaseline,
      textAlignVertical: textAlignVertical,
      isFocused: isFocused,
      expands: expands,
      material3: Theme.of(context).useMaterial3,
    );
  }

  @override
  void updateRenderObject(BuildContext context, _RenderDecoration renderObject) {
    renderObject
     ..decoration = decoration
     ..expands = expands
     ..isFocused = isFocused
     ..textAlignVertical = textAlignVertical
     ..textBaseline = textBaseline
     ..textDirection = textDirection;
  }
}

class _AffixText extends StatelessWidget {
  const _AffixText({
    required this.labelIsFloating,
    this.text,
    this.style,
    this.child,
    this.semanticsSortKey,
    required this.semanticsTag,
  });

  final bool labelIsFloating;
  final String? text;
  final TextStyle? style;
  final Widget? child;
  final SemanticsSortKey? semanticsSortKey;
  final SemanticsTag semanticsTag;

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle.merge(
      style: style,
      child: AnimatedOpacity(
        duration: _kTransitionDuration,
        curve: _kTransitionCurve,
        opacity: labelIsFloating ? 1.0 : 0.0,
        child: Semantics(
          sortKey: semanticsSortKey,
          tagForChildren: semanticsTag,
          child: child ?? (text == null ? null : Text(text!, style: style)),
        ),
      ),
    );
  }
}

class InputDecorator extends StatefulWidget {
  const InputDecorator({
    super.key,
    required this.decoration,
    this.baseStyle,
    this.textAlign,
    this.textAlignVertical,
    this.isFocused = false,
    this.isHovering = false,
    this.expands = false,
    this.isEmpty = false,
    this.child,
  });

  final InputDecoration decoration;

  final TextStyle? baseStyle;

  final TextAlign? textAlign;

  final TextAlignVertical? textAlignVertical;

  final bool isFocused;

  final bool isHovering;

  final bool expands;

  final bool isEmpty;

  final Widget? child;

  bool get _labelShouldWithdraw => !isEmpty || (isFocused && decoration.enabled);

  @override
  State<InputDecorator> createState() => _InputDecoratorState();

  static RenderBox? containerOf(BuildContext context) {
    final _RenderDecoration? result = context.findAncestorRenderObjectOfType<_RenderDecoration>();
    return result?.container;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<InputDecoration>('decoration', decoration));
    properties.add(DiagnosticsProperty<TextStyle>('baseStyle', baseStyle, defaultValue: null));
    properties.add(DiagnosticsProperty<bool>('isFocused', isFocused));
    properties.add(DiagnosticsProperty<bool>('expands', expands, defaultValue: false));
    properties.add(DiagnosticsProperty<bool>('isEmpty', isEmpty));
  }
}

class _InputDecoratorState extends State<InputDecorator> with TickerProviderStateMixin {
  late final AnimationController _floatingLabelController;
  late final Animation<double> _floatingLabelAnimation;
  late final AnimationController _shakingLabelController;
  final _InputBorderGap _borderGap = _InputBorderGap();
  static const OrdinalSortKey _kPrefixSemanticsSortOrder = OrdinalSortKey(0);
  static const OrdinalSortKey _kInputSemanticsSortOrder = OrdinalSortKey(1);
  static const OrdinalSortKey _kSuffixSemanticsSortOrder = OrdinalSortKey(2);
  static const SemanticsTag _kPrefixSemanticsTag = SemanticsTag('_InputDecoratorState.prefix');
  static const SemanticsTag _kSuffixSemanticsTag = SemanticsTag('_InputDecoratorState.suffix');

  @override
  void initState() {
    super.initState();

    final bool labelIsInitiallyFloating = widget.decoration.floatingLabelBehavior == FloatingLabelBehavior.always
        || (widget.decoration.floatingLabelBehavior != FloatingLabelBehavior.never &&
            widget._labelShouldWithdraw);

    _floatingLabelController = AnimationController(
      duration: _kTransitionDuration,
      vsync: this,
      value: labelIsInitiallyFloating ? 1.0 : 0.0,
    );
    _floatingLabelController.addListener(_handleChange);
    _floatingLabelAnimation = CurvedAnimation(
      parent: _floatingLabelController,
      curve: _kTransitionCurve,
      reverseCurve: _kTransitionCurve.flipped,
    );

    _shakingLabelController = AnimationController(
      duration: _kTransitionDuration,
      vsync: this,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _effectiveDecoration = null;
  }

  @override
  void dispose() {
    _floatingLabelController.dispose();
    _shakingLabelController.dispose();
    _borderGap.dispose();
    super.dispose();
  }

  void _handleChange() {
    setState(() {
      // The _floatingLabelController's value has changed.
    });
  }

  InputDecoration? _effectiveDecoration;
  InputDecoration get decoration => _effectiveDecoration ??= widget.decoration.applyDefaults(Theme.of(context).inputDecorationTheme);

  TextAlign? get textAlign => widget.textAlign;
  bool get isFocused => widget.isFocused;
  bool get _hasError => decoration.errorText != null || decoration.error != null;
  bool get isHovering => widget.isHovering && decoration.enabled;
  bool get isEmpty => widget.isEmpty;
  bool get _floatingLabelEnabled {
    return decoration.floatingLabelBehavior != FloatingLabelBehavior.never;
  }

  @override
  void didUpdateWidget(InputDecorator old) {
    super.didUpdateWidget(old);
    if (widget.decoration != old.decoration) {
      _effectiveDecoration = null;
    }

    final bool floatBehaviorChanged = widget.decoration.floatingLabelBehavior != old.decoration.floatingLabelBehavior;

    if (widget._labelShouldWithdraw != old._labelShouldWithdraw || floatBehaviorChanged) {
      if (_floatingLabelEnabled
          && (widget._labelShouldWithdraw || widget.decoration.floatingLabelBehavior == FloatingLabelBehavior.always)) {
        _floatingLabelController.forward();
      } else {
        _floatingLabelController.reverse();
      }
    }

    final String? errorText = decoration.errorText;
    final String? oldErrorText = old.decoration.errorText;

    if (_floatingLabelController.isCompleted && errorText != null && errorText != oldErrorText) {
      _shakingLabelController
        ..value = 0.0
        ..forward();
    }
  }

  Color _getDefaultM2BorderColor(ThemeData themeData) {
    if (!decoration.enabled && !isFocused) {
      return ((decoration.filled ?? false) && !(decoration.border?.isOutline ?? false))
          ? Colors.transparent
          : themeData.disabledColor;
    }
    if (_hasError) {
      return themeData.colorScheme.error;
    }
    if (isFocused) {
      return themeData.colorScheme.primary;
    }
    if (decoration.filled!) {
      return themeData.hintColor;
    }
    final Color enabledColor = themeData.colorScheme.onSurface.withOpacity(0.38);
    if (isHovering) {
      final Color hoverColor = decoration.hoverColor ?? themeData.inputDecorationTheme.hoverColor ?? themeData.hoverColor;
      return Color.alphaBlend(hoverColor.withOpacity(0.12), enabledColor);
    }
    return enabledColor;
  }

  Color _getFillColor(ThemeData themeData, InputDecorationTheme defaults) {
    if (decoration.filled != true) { // filled == null same as filled == false
      return Colors.transparent;
    }
    if (decoration.fillColor != null) {
      return MaterialStateProperty.resolveAs(decoration.fillColor!, materialState);
    }
    return MaterialStateProperty.resolveAs(defaults.fillColor!, materialState);
  }

  Color _getHoverColor(ThemeData themeData) {
    if (decoration.filled == null || !decoration.filled! || isFocused || !decoration.enabled) {
      return Colors.transparent;
    }
    return decoration.hoverColor ?? themeData.inputDecorationTheme.hoverColor ?? themeData.hoverColor;
  }

  Color _getIconColor(ThemeData themeData, InputDecorationTheme defaults) {
    return  MaterialStateProperty.resolveAs(decoration.iconColor, materialState)
      ?? MaterialStateProperty.resolveAs(themeData.inputDecorationTheme.iconColor, materialState)
      ?? MaterialStateProperty.resolveAs(defaults.iconColor!, materialState);
  }

  Color _getPrefixIconColor(ThemeData themeData, InputDecorationTheme defaults) {
    return MaterialStateProperty.resolveAs(decoration.prefixIconColor, materialState)
      ?? MaterialStateProperty.resolveAs(themeData.inputDecorationTheme.prefixIconColor, materialState)
      ?? MaterialStateProperty.resolveAs(defaults.prefixIconColor!, materialState);
  }

  Color _getSuffixIconColor(ThemeData themeData, InputDecorationTheme defaults) {
    return MaterialStateProperty.resolveAs(decoration.suffixIconColor, materialState)
      ?? MaterialStateProperty.resolveAs(themeData.inputDecorationTheme.suffixIconColor, materialState)
      ?? MaterialStateProperty.resolveAs(defaults.suffixIconColor!, materialState);
  }

  // True if the label will be shown and the hint will not.
  // If we're not focused, there's no value, labelText was provided, and
  // floatingLabelBehavior isn't set to always, then the label appears where the
  // hint would.
  bool get _hasInlineLabel {
    return !widget._labelShouldWithdraw
        && (decoration.labelText != null || decoration.label != null)
        && decoration.floatingLabelBehavior != FloatingLabelBehavior.always;
  }

  // If the label is a floating placeholder, it's always shown.
  bool get _shouldShowLabel => _hasInlineLabel || _floatingLabelEnabled;

  // The base style for the inline label when they're displayed "inline",
  // i.e. when they appear in place of the empty text field.
  TextStyle _getInlineLabelStyle(ThemeData themeData, InputDecorationTheme defaults) {
    final TextStyle defaultStyle = MaterialStateProperty.resolveAs(defaults.labelStyle!, materialState);

    final TextStyle? style = MaterialStateProperty.resolveAs(decoration.labelStyle, materialState)
      ?? MaterialStateProperty.resolveAs(themeData.inputDecorationTheme.labelStyle, materialState);

    return themeData.textTheme.titleMedium!
      .merge(widget.baseStyle)
      .merge(defaultStyle)
      .merge(style)
      .copyWith(height: 1);
  }

  // The base style for the inline hint when they're displayed "inline",
  // i.e. when they appear in place of the empty text field.
  TextStyle _getInlineHintStyle(ThemeData themeData, InputDecorationTheme defaults) {
    final TextStyle defaultStyle = MaterialStateProperty.resolveAs(defaults.hintStyle!, materialState);

    final TextStyle? style = MaterialStateProperty.resolveAs(decoration.hintStyle, materialState)
      ?? MaterialStateProperty.resolveAs(themeData.inputDecorationTheme.hintStyle, materialState);

    return themeData.textTheme.titleMedium!
      .merge(widget.baseStyle)
      .merge(defaultStyle)
      .merge(style);
  }

  TextStyle _getFloatingLabelStyle(ThemeData themeData, InputDecorationTheme defaults) {
    TextStyle defaultTextStyle = MaterialStateProperty.resolveAs(defaults.floatingLabelStyle!, materialState);
    if (_hasError && decoration.errorStyle?.color != null) {
      defaultTextStyle = defaultTextStyle.copyWith(color: decoration.errorStyle?.color);
    }
    defaultTextStyle = defaultTextStyle.merge(decoration.floatingLabelStyle ?? decoration.labelStyle);

    final TextStyle? style = MaterialStateProperty.resolveAs(decoration.floatingLabelStyle, materialState)
      ?? MaterialStateProperty.resolveAs(themeData.inputDecorationTheme.floatingLabelStyle, materialState);

    return themeData.textTheme.titleMedium!
      .merge(widget.baseStyle)
      .copyWith(height: 1)
      .merge(defaultTextStyle)
      .merge(style);
  }

  TextStyle _getHelperStyle(ThemeData themeData, InputDecorationTheme defaults) {
    return MaterialStateProperty.resolveAs(defaults.helperStyle!, materialState)
      .merge(MaterialStateProperty.resolveAs(decoration.helperStyle, materialState));
  }

  TextStyle _getErrorStyle(ThemeData themeData, InputDecorationTheme defaults) {
    return MaterialStateProperty.resolveAs(defaults.errorStyle!, materialState)
      .merge(decoration.errorStyle);
  }

  Set<MaterialState> get materialState {
    return <MaterialState>{
      if (!decoration.enabled) MaterialState.disabled,
      if (isFocused) MaterialState.focused,
      if (isHovering) MaterialState.hovered,
      if (_hasError) MaterialState.error,
    };
  }


  InputBorder _getDefaultBorder(ThemeData themeData, InputDecorationTheme defaults) {
    final InputBorder border =  MaterialStateProperty.resolveAs(decoration.border, materialState)
      ?? const UnderlineInputBorder();

    if (decoration.border is MaterialStateProperty<InputBorder>) {
      return border;
    }

    if (border.borderSide == BorderSide.none) {
      return border;
    }

    if (themeData.useMaterial3) {
      if (decoration.filled!) {
        return border.copyWith(
          borderSide: MaterialStateProperty.resolveAs(defaults.activeIndicatorBorder, materialState),
        );
      } else {
        return border.copyWith(
          borderSide: MaterialStateProperty.resolveAs(defaults.outlineBorder, materialState),
        );
      }
    }
    else{
      return border.copyWith(
        borderSide: BorderSide(
          color: _getDefaultM2BorderColor(themeData),
          width: (
              (decoration.isCollapsed ?? themeData.inputDecorationTheme.isCollapsed)
                  || decoration.border == InputBorder.none
                  || !decoration.enabled)
            ? 0.0
            : isFocused ? 2.0 : 1.0,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData themeData = Theme.of(context);
    final InputDecorationTheme defaults =
      Theme.of(context).useMaterial3 ? _InputDecoratorDefaultsM3(context) :  _InputDecoratorDefaultsM2(context);

    final TextStyle labelStyle = _getInlineLabelStyle(themeData, defaults);
    final TextBaseline textBaseline = labelStyle.textBaseline!;

    final TextStyle hintStyle = _getInlineHintStyle(themeData, defaults);
    final String? hintText = decoration.hintText;
    final Widget? hint = hintText == null ? null : AnimatedOpacity(
      opacity: (isEmpty && !_hasInlineLabel) ? 1.0 : 0.0,
      duration: decoration.hintFadeDuration ?? _kHintFadeTransitionDuration,
      curve: _kTransitionCurve,
      child: Text(
        hintText,
        style: hintStyle,
        textDirection: decoration.hintTextDirection,
        overflow: hintStyle.overflow ?? TextOverflow.ellipsis,
        textAlign: textAlign,
        maxLines: decoration.hintMaxLines,
      ),
    );

    InputBorder? border;
    if (!decoration.enabled) {
      border = _hasError ? decoration.errorBorder : decoration.disabledBorder;
    } else if (isFocused) {
      border = _hasError ? decoration.focusedErrorBorder : decoration.focusedBorder;
    } else {
      border = _hasError ? decoration.errorBorder : decoration.enabledBorder;
    }
    border ??= _getDefaultBorder(themeData, defaults);

    final Widget container = _BorderContainer(
      border: border,
      gap: _borderGap,
      gapAnimation: _floatingLabelAnimation,
      fillColor: _getFillColor(themeData, defaults),
      hoverColor: _getHoverColor(themeData),
      isHovering: isHovering,
    );

    final Widget? label = decoration.labelText == null && decoration.label == null ? null : _Shaker(
      animation: _shakingLabelController.view,
      child: AnimatedOpacity(
        duration: _kTransitionDuration,
        curve: _kTransitionCurve,
        opacity: _shouldShowLabel ? 1.0 : 0.0,
        child: AnimatedDefaultTextStyle(
          duration:_kTransitionDuration,
          curve: _kTransitionCurve,
          style: widget._labelShouldWithdraw
            ? _getFloatingLabelStyle(themeData, defaults)
            : labelStyle,
          child: decoration.label ?? Text(
            decoration.labelText!,
            overflow: TextOverflow.ellipsis,
            textAlign: textAlign,
          ),
        ),
      ),
    );

    final bool hasPrefix = decoration.prefix != null || decoration.prefixText != null;
    final bool hasSuffix = decoration.suffix != null || decoration.suffixText != null;

    Widget? input = widget.child;
    // If at least two out of the three are visible, it needs semantics sort
    // order.
    final bool needsSemanticsSortOrder = widget._labelShouldWithdraw && (input != null ? (hasPrefix || hasSuffix) : (hasPrefix && hasSuffix));

    final Widget? prefix = hasPrefix
      ? _AffixText(
          labelIsFloating: widget._labelShouldWithdraw,
          text: decoration.prefixText,
          style: MaterialStateProperty.resolveAs(decoration.prefixStyle, materialState) ?? hintStyle,
          semanticsSortKey: needsSemanticsSortOrder ? _kPrefixSemanticsSortOrder : null,
          semanticsTag: _kPrefixSemanticsTag,
          child: decoration.prefix,
        )
      : null;

    final Widget? suffix = hasSuffix
      ? _AffixText(
          labelIsFloating: widget._labelShouldWithdraw,
          text: decoration.suffixText,
          style: MaterialStateProperty.resolveAs(decoration.suffixStyle, materialState) ?? hintStyle,
          semanticsSortKey: needsSemanticsSortOrder ? _kSuffixSemanticsSortOrder : null,
          semanticsTag: _kSuffixSemanticsTag,
          child: decoration.suffix,
        )
      : null;

    if (input != null && needsSemanticsSortOrder) {
      input = Semantics(
        sortKey: _kInputSemanticsSortOrder,
        child: input,
      );
    }

    final bool decorationIsDense = decoration.isDense ?? false;
    final double iconSize = decorationIsDense ? 18.0 : 24.0;

    final Widget? icon = decoration.icon == null ? null :
      MouseRegion(
        cursor: SystemMouseCursors.basic,
        child: Padding(
          padding: const EdgeInsetsDirectional.only(end: 16.0),
          child: IconTheme.merge(
            data: IconThemeData(
              color: _getIconColor(themeData, defaults),
              size: iconSize,
            ),
            child: decoration.icon!,
          ),
        ),
      );

    final Widget? prefixIcon = decoration.prefixIcon == null ? null :
      Center(
        widthFactor: 1.0,
        heightFactor: 1.0,
        child: MouseRegion(
          cursor: SystemMouseCursors.basic,
          child: ConstrainedBox(
            constraints: decoration.prefixIconConstraints ??
              themeData.visualDensity.effectiveConstraints(
                const BoxConstraints(
                  minWidth: kMinInteractiveDimension,
                  minHeight: kMinInteractiveDimension,
                ),
              ),
            child: IconTheme.merge(
              data: IconThemeData(
                color: _getPrefixIconColor(themeData, defaults),
                size: iconSize,
              ),
              child: IconButtonTheme(
                data: IconButtonThemeData(
                style: IconButton.styleFrom(
                  foregroundColor: _getPrefixIconColor(themeData, defaults),
                  iconSize: iconSize,
                  ),
                ),
                child: Semantics(
                  child: decoration.prefixIcon,
                ),
              ),
            ),
          ),
        ),
      );

    final Widget? suffixIcon = decoration.suffixIcon == null ? null :
      Center(
        widthFactor: 1.0,
        heightFactor: 1.0,
        child: MouseRegion(
          cursor: SystemMouseCursors.basic,
          child: ConstrainedBox(
            constraints: decoration.suffixIconConstraints ??
              themeData.visualDensity.effectiveConstraints(
                const BoxConstraints(
                  minWidth: kMinInteractiveDimension,
                  minHeight: kMinInteractiveDimension,
                ),
              ),
              child: IconTheme.merge(
                data: IconThemeData(
                  color: _getSuffixIconColor(themeData, defaults),
                  size: iconSize,
                ),
                child: IconButtonTheme(
                  data: IconButtonThemeData(
                  style: IconButton.styleFrom(
                    foregroundColor: _getSuffixIconColor(themeData, defaults),
                    iconSize: iconSize,
                    ),
                  ),
                  child: Semantics(
                    child: decoration.suffixIcon,
                  ),
                ),
              ),
            ),
          ),
        );

    final Widget helperError = _HelperError(
      textAlign: textAlign,
      helperText: decoration.helperText,
      helperStyle: _getHelperStyle(themeData, defaults),
      helperMaxLines: decoration.helperMaxLines,
      error: decoration.error,
      errorText: decoration.errorText,
      errorStyle: _getErrorStyle(themeData, defaults),
      errorMaxLines: decoration.errorMaxLines,
    );

    Widget? counter;
    if (decoration.counter != null) {
      counter = decoration.counter;
    } else if (decoration.counterText != null && decoration.counterText != '') {
      counter = Semantics(
        container: true,
        liveRegion: isFocused,
        child: Text(
          decoration.counterText!,
          style: _getHelperStyle(themeData, defaults).merge(MaterialStateProperty.resolveAs(decoration.counterStyle, materialState)),
          overflow: TextOverflow.ellipsis,
          semanticsLabel: decoration.semanticCounterText,
        ),
      );
    }

    // The _Decoration widget and _RenderDecoration assume that contentPadding
    // has been resolved to EdgeInsets.
    final TextDirection textDirection = Directionality.of(context);
    final EdgeInsets? decorationContentPadding = decoration.contentPadding?.resolve(textDirection);

    final EdgeInsets contentPadding;
    final double floatingLabelHeight;
    if (decoration.isCollapsed
        ?? themeData.inputDecorationTheme.isCollapsed) {
      floatingLabelHeight = 0.0;
      contentPadding = decorationContentPadding ?? EdgeInsets.zero;
    } else if (!border.isOutline) {
      // 4.0: the vertical gap between the inline elements and the floating label.
      floatingLabelHeight = (4.0 + 0.75 * labelStyle.fontSize!) * MediaQuery.textScalerOf(context).textScaleFactor;
      if (decoration.filled ?? false) {
        contentPadding = decorationContentPadding ?? (decorationIsDense
          ? const EdgeInsets.fromLTRB(12.0, 8.0, 12.0, 8.0)
          : const EdgeInsets.fromLTRB(12.0, 12.0, 12.0, 12.0));
      } else {
        // Not left or right padding for underline borders that aren't filled
        // is a small concession to backwards compatibility. This eliminates
        // the most noticeable layout change introduced by #13734.
        contentPadding = decorationContentPadding ?? (decorationIsDense
          ? const EdgeInsets.fromLTRB(0.0, 8.0, 0.0, 8.0)
          : const EdgeInsets.fromLTRB(0.0, 12.0, 0.0, 12.0));
      }
    } else {
      floatingLabelHeight = 0.0;
      contentPadding = decorationContentPadding ?? (decorationIsDense
        ? const EdgeInsets.fromLTRB(12.0, 20.0, 12.0, 12.0)
        : const EdgeInsets.fromLTRB(12.0, 24.0, 12.0, 16.0));
    }

    final _Decorator decorator = _Decorator(
      decoration: _Decoration(
        contentPadding: contentPadding,
        isCollapsed: decoration.isCollapsed ?? themeData.inputDecorationTheme.isCollapsed,
        floatingLabelHeight: floatingLabelHeight,
        floatingLabelAlignment: decoration.floatingLabelAlignment!,
        floatingLabelProgress: _floatingLabelAnimation.value,
        border: border,
        borderGap: _borderGap,
        alignLabelWithHint: decoration.alignLabelWithHint ?? false,
        isDense: decoration.isDense,
        visualDensity: themeData.visualDensity,
        icon: icon,
        input: input,
        label: label,
        hint: hint,
        prefix: prefix,
        suffix: suffix,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        helperError: helperError,
        counter: counter,
        container: container
      ),
      textDirection: textDirection,
      textBaseline: textBaseline,
      textAlignVertical: widget.textAlignVertical,
      isFocused: isFocused,
      expands: widget.expands,
    );

    final BoxConstraints? constraints = decoration.constraints ?? themeData.inputDecorationTheme.constraints;
    if (constraints != null) {
      return ConstrainedBox(
        constraints: constraints,
        child: decorator,
      );
    }
    return decorator;
  }
}

@immutable
class InputDecoration {
  const InputDecoration({
    this.icon,
    this.iconColor,
    this.label,
    this.labelText,
    this.labelStyle,
    this.floatingLabelStyle,
    this.helperText,
    this.helperStyle,
    this.helperMaxLines,
    this.hintText,
    this.hintStyle,
    this.hintTextDirection,
    this.hintMaxLines,
    this.hintFadeDuration,
    this.error,
    this.errorText,
    this.errorStyle,
    this.errorMaxLines,
    this.floatingLabelBehavior,
    this.floatingLabelAlignment,
    this.isCollapsed,
    this.isDense,
    this.contentPadding,
    this.prefixIcon,
    this.prefixIconConstraints,
    this.prefix,
    this.prefixText,
    this.prefixStyle,
    this.prefixIconColor,
    this.suffixIcon,
    this.suffix,
    this.suffixText,
    this.suffixStyle,
    this.suffixIconColor,
    this.suffixIconConstraints,
    this.counter,
    this.counterText,
    this.counterStyle,
    this.filled,
    this.fillColor,
    this.focusColor,
    this.hoverColor,
    this.errorBorder,
    this.focusedBorder,
    this.focusedErrorBorder,
    this.disabledBorder,
    this.enabledBorder,
    this.border,
    this.enabled = true,
    this.semanticCounterText,
    this.alignLabelWithHint,
    this.constraints,
  }) : assert(!(label != null && labelText != null), 'Declaring both label and labelText is not supported.'),
       assert(!(prefix != null && prefixText != null), 'Declaring both prefix and prefixText is not supported.'),
       assert(!(suffix != null && suffixText != null), 'Declaring both suffix and suffixText is not supported.'),
       assert(!(error != null && errorText != null), 'Declaring both error and errorText is not supported.');

  const InputDecoration.collapsed({
    required this.hintText,
    this.floatingLabelBehavior,
    this.floatingLabelAlignment,
    this.hintStyle,
    this.hintTextDirection,
    this.filled = false,
    this.fillColor,
    this.focusColor,
    this.hoverColor,
    this.border = InputBorder.none,
    this.enabled = true,
  }) : icon = null,
       iconColor = null,
       label = null,
       labelText = null,
       labelStyle = null,
       floatingLabelStyle = null,
       helperText = null,
       helperStyle = null,
       helperMaxLines = null,
       hintMaxLines = null,
       hintFadeDuration = null,
       error = null,
       errorText = null,
       errorStyle = null,
       errorMaxLines = null,
       isDense = false,
       contentPadding = EdgeInsets.zero,
       isCollapsed = true,
       prefixIcon = null,
       prefix = null,
       prefixText = null,
       prefixStyle = null,
       prefixIconColor = null,
       prefixIconConstraints = null,
       suffix = null,
       suffixIcon = null,
       suffixText = null,
       suffixStyle = null,
       suffixIconColor = null,
       suffixIconConstraints = null,
       counter = null,
       counterText = null,
       counterStyle = null,
       errorBorder = null,
       focusedBorder = null,
       focusedErrorBorder = null,
       disabledBorder = null,
       enabledBorder = null,
       semanticCounterText = null,
       alignLabelWithHint = false,
       constraints = null;

  final Widget? icon;

  final Color? iconColor;

  final Widget? label;

  final String? labelText;

  final TextStyle? labelStyle;

  final TextStyle? floatingLabelStyle;

  final String? helperText;

  final TextStyle? helperStyle;

  final int? helperMaxLines;

  final String? hintText;

  final TextStyle? hintStyle;

  final TextDirection? hintTextDirection;

  final int? hintMaxLines;

  final Duration? hintFadeDuration;

  final Widget? error;

  final String? errorText;

  final TextStyle? errorStyle;


  final int? errorMaxLines;

  final FloatingLabelBehavior? floatingLabelBehavior;

  final FloatingLabelAlignment? floatingLabelAlignment;

  final bool? isDense;

  final EdgeInsetsGeometry? contentPadding;

  final bool? isCollapsed;

  final Widget? prefixIcon;

  final BoxConstraints? prefixIconConstraints;

  final Widget? prefix;

  final String? prefixText;

  final TextStyle? prefixStyle;

  final Color? prefixIconColor;

  final Widget? suffixIcon;

  final Widget? suffix;

  final String? suffixText;

  final TextStyle? suffixStyle;

  final Color? suffixIconColor;

  final BoxConstraints? suffixIconConstraints;

  final String? counterText;

  final Widget? counter;

  final TextStyle? counterStyle;

  final bool? filled;

  final Color? fillColor;

  final Color? focusColor;

  final Color? hoverColor;

  final InputBorder? errorBorder;

  final InputBorder? focusedBorder;

  final InputBorder? focusedErrorBorder;

  final InputBorder? disabledBorder;

  final InputBorder? enabledBorder;

  final InputBorder? border;

  final bool enabled;

  final String? semanticCounterText;

  final bool? alignLabelWithHint;

  final BoxConstraints? constraints;

  InputDecoration copyWith({
    Widget? icon,
    Color? iconColor,
    Widget? label,
    String? labelText,
    TextStyle? labelStyle,
    TextStyle? floatingLabelStyle,
    String? helperText,
    TextStyle? helperStyle,
    int? helperMaxLines,
    String? hintText,
    TextStyle? hintStyle,
    TextDirection? hintTextDirection,
    Duration? hintFadeDuration,
    int? hintMaxLines,
    Widget? error,
    String? errorText,
    TextStyle? errorStyle,
    int? errorMaxLines,
    FloatingLabelBehavior? floatingLabelBehavior,
    FloatingLabelAlignment? floatingLabelAlignment,
    bool? isCollapsed,
    bool? isDense,
    EdgeInsetsGeometry? contentPadding,
    Widget? prefixIcon,
    Widget? prefix,
    String? prefixText,
    BoxConstraints? prefixIconConstraints,
    TextStyle? prefixStyle,
    Color? prefixIconColor,
    Widget? suffixIcon,
    Widget? suffix,
    String? suffixText,
    TextStyle? suffixStyle,
    Color? suffixIconColor,
    BoxConstraints? suffixIconConstraints,
    Widget? counter,
    String? counterText,
    TextStyle? counterStyle,
    bool? filled,
    Color? fillColor,
    Color? focusColor,
    Color? hoverColor,
    InputBorder? errorBorder,
    InputBorder? focusedBorder,
    InputBorder? focusedErrorBorder,
    InputBorder? disabledBorder,
    InputBorder? enabledBorder,
    InputBorder? border,
    bool? enabled,
    String? semanticCounterText,
    bool? alignLabelWithHint,
    BoxConstraints? constraints,
  }) {
    return InputDecoration(
      icon: icon ?? this.icon,
      iconColor: iconColor ?? this.iconColor,
      label: label ?? this.label,
      labelText: labelText ?? this.labelText,
      labelStyle: labelStyle ?? this.labelStyle,
      floatingLabelStyle: floatingLabelStyle ?? this.floatingLabelStyle,
      helperText: helperText ?? this.helperText,
      helperStyle: helperStyle ?? this.helperStyle,
      helperMaxLines : helperMaxLines ?? this.helperMaxLines,
      hintText: hintText ?? this.hintText,
      hintStyle: hintStyle ?? this.hintStyle,
      hintTextDirection: hintTextDirection ?? this.hintTextDirection,
      hintMaxLines: hintMaxLines ?? this.hintMaxLines,
      hintFadeDuration: hintFadeDuration ?? this.hintFadeDuration,
      error: error ?? this.error,
      errorText: errorText ?? this.errorText,
      errorStyle: errorStyle ?? this.errorStyle,
      errorMaxLines: errorMaxLines ?? this.errorMaxLines,
      floatingLabelBehavior: floatingLabelBehavior ?? this.floatingLabelBehavior,
      floatingLabelAlignment: floatingLabelAlignment ?? this.floatingLabelAlignment,
      isCollapsed: isCollapsed ?? this.isCollapsed,
      isDense: isDense ?? this.isDense,
      contentPadding: contentPadding ?? this.contentPadding,
      prefixIcon: prefixIcon ?? this.prefixIcon,
      prefix: prefix ?? this.prefix,
      prefixText: prefixText ?? this.prefixText,
      prefixStyle: prefixStyle ?? this.prefixStyle,
      prefixIconColor: prefixIconColor ?? this.prefixIconColor,
      prefixIconConstraints: prefixIconConstraints ?? this.prefixIconConstraints,
      suffixIcon: suffixIcon ?? this.suffixIcon,
      suffix: suffix ?? this.suffix,
      suffixText: suffixText ?? this.suffixText,
      suffixStyle: suffixStyle ?? this.suffixStyle,
      suffixIconColor: suffixIconColor ?? this.suffixIconColor,
      suffixIconConstraints: suffixIconConstraints ?? this.suffixIconConstraints,
      counter: counter ?? this.counter,
      counterText: counterText ?? this.counterText,
      counterStyle: counterStyle ?? this.counterStyle,
      filled: filled ?? this.filled,
      fillColor: fillColor ?? this.fillColor,
      focusColor: focusColor ?? this.focusColor,
      hoverColor: hoverColor ?? this.hoverColor,
      errorBorder: errorBorder ?? this.errorBorder,
      focusedBorder: focusedBorder ?? this.focusedBorder,
      focusedErrorBorder: focusedErrorBorder ?? this.focusedErrorBorder,
      disabledBorder: disabledBorder ?? this.disabledBorder,
      enabledBorder: enabledBorder ?? this.enabledBorder,
      border: border ?? this.border,
      enabled: enabled ?? this.enabled,
      semanticCounterText: semanticCounterText ?? this.semanticCounterText,
      alignLabelWithHint: alignLabelWithHint ?? this.alignLabelWithHint,
      constraints: constraints ?? this.constraints,
    );
  }

  InputDecoration applyDefaults(InputDecorationTheme theme) {
    return copyWith(
      labelStyle: labelStyle ?? theme.labelStyle,
      floatingLabelStyle: floatingLabelStyle ?? theme.floatingLabelStyle,
      helperStyle: helperStyle ?? theme.helperStyle,
      helperMaxLines : helperMaxLines ?? theme.helperMaxLines,
      hintStyle: hintStyle ?? theme.hintStyle,
      hintFadeDuration: hintFadeDuration ?? theme.hintFadeDuration,
      errorStyle: errorStyle ?? theme.errorStyle,
      errorMaxLines: errorMaxLines ?? theme.errorMaxLines,
      floatingLabelBehavior: floatingLabelBehavior ?? theme.floatingLabelBehavior,
      floatingLabelAlignment: floatingLabelAlignment ?? theme.floatingLabelAlignment,
      isDense: isDense ?? theme.isDense,
      contentPadding: contentPadding ?? theme.contentPadding,
      isCollapsed: isCollapsed ?? theme.isCollapsed,
      iconColor: iconColor ?? theme.iconColor,
      prefixStyle: prefixStyle ?? theme.prefixStyle,
      prefixIconColor: prefixIconColor ?? theme.prefixIconColor,
      suffixStyle: suffixStyle ?? theme.suffixStyle,
      suffixIconColor: suffixIconColor ?? theme.suffixIconColor,
      counterStyle: counterStyle ?? theme.counterStyle,
      filled: filled ?? theme.filled,
      fillColor: fillColor ?? theme.fillColor,
      focusColor: focusColor ?? theme.focusColor,
      hoverColor: hoverColor ?? theme.hoverColor,
      errorBorder: errorBorder ?? theme.errorBorder,
      focusedBorder: focusedBorder ?? theme.focusedBorder,
      focusedErrorBorder: focusedErrorBorder ?? theme.focusedErrorBorder,
      disabledBorder: disabledBorder ?? theme.disabledBorder,
      enabledBorder: enabledBorder ?? theme.enabledBorder,
      border: border ?? theme.border,
      alignLabelWithHint: alignLabelWithHint ?? theme.alignLabelWithHint,
      constraints: constraints ?? theme.constraints,
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
    return other is InputDecoration
        && other.icon == icon
        && other.iconColor == iconColor
        && other.label == label
        && other.labelText == labelText
        && other.labelStyle == labelStyle
        && other.floatingLabelStyle == floatingLabelStyle
        && other.helperText == helperText
        && other.helperStyle == helperStyle
        && other.helperMaxLines == helperMaxLines
        && other.hintText == hintText
        && other.hintStyle == hintStyle
        && other.hintTextDirection == hintTextDirection
        && other.hintMaxLines == hintMaxLines
        && other.hintFadeDuration == hintFadeDuration
        && other.error == error
        && other.errorText == errorText
        && other.errorStyle == errorStyle
        && other.errorMaxLines == errorMaxLines
        && other.floatingLabelBehavior == floatingLabelBehavior
        && other.floatingLabelAlignment == floatingLabelAlignment
        && other.isDense == isDense
        && other.contentPadding == contentPadding
        && other.isCollapsed == isCollapsed
        && other.prefixIcon == prefixIcon
        && other.prefixIconColor == prefixIconColor
        && other.prefix == prefix
        && other.prefixText == prefixText
        && other.prefixStyle == prefixStyle
        && other.prefixIconConstraints == prefixIconConstraints
        && other.suffixIcon == suffixIcon
        && other.suffixIconColor == suffixIconColor
        && other.suffix == suffix
        && other.suffixText == suffixText
        && other.suffixStyle == suffixStyle
        && other.suffixIconConstraints == suffixIconConstraints
        && other.counter == counter
        && other.counterText == counterText
        && other.counterStyle == counterStyle
        && other.filled == filled
        && other.fillColor == fillColor
        && other.focusColor == focusColor
        && other.hoverColor == hoverColor
        && other.errorBorder == errorBorder
        && other.focusedBorder == focusedBorder
        && other.focusedErrorBorder == focusedErrorBorder
        && other.disabledBorder == disabledBorder
        && other.enabledBorder == enabledBorder
        && other.border == border
        && other.enabled == enabled
        && other.semanticCounterText == semanticCounterText
        && other.alignLabelWithHint == alignLabelWithHint
        && other.constraints == constraints;
  }

  @override
  int get hashCode {
    final List<Object?> values = <Object?>[
      icon,
      iconColor,
      label,
      labelText,
      floatingLabelStyle,
      labelStyle,
      helperText,
      helperStyle,
      helperMaxLines,
      hintText,
      hintStyle,
      hintTextDirection,
      hintMaxLines,
      hintFadeDuration,
      error,
      errorText,
      errorStyle,
      errorMaxLines,
      floatingLabelBehavior,
      floatingLabelAlignment,
      isDense,
      contentPadding,
      isCollapsed,
      filled,
      fillColor,
      focusColor,
      hoverColor,
      prefixIcon,
      prefixIconColor,
      prefix,
      prefixText,
      prefixStyle,
      prefixIconConstraints,
      suffixIcon,
      suffixIconColor,
      suffix,
      suffixText,
      suffixStyle,
      suffixIconConstraints,
      counter,
      counterText,
      counterStyle,
      errorBorder,
      focusedBorder,
      focusedErrorBorder,
      disabledBorder,
      enabledBorder,
      border,
      enabled,
      semanticCounterText,
      alignLabelWithHint,
      constraints,
    ];
    return Object.hashAll(values);
  }

  @override
  String toString() {
    final List<String> description = <String>[
      if (icon != null) 'icon: $icon',
      if (iconColor != null) 'iconColor: $iconColor',
      if (label != null) 'label: $label',
      if (labelText != null) 'labelText: "$labelText"',
      if (floatingLabelStyle != null) 'floatingLabelStyle: "$floatingLabelStyle"',
      if (helperText != null) 'helperText: "$helperText"',
      if (helperMaxLines != null) 'helperMaxLines: "$helperMaxLines"',
      if (hintText != null) 'hintText: "$hintText"',
      if (hintMaxLines != null) 'hintMaxLines: "$hintMaxLines"',
      if (hintFadeDuration != null) 'hintFadeDuration: "$hintFadeDuration"',
      if (error != null) 'error: "$error"',
      if (errorText != null) 'errorText: "$errorText"',
      if (errorStyle != null) 'errorStyle: "$errorStyle"',
      if (errorMaxLines != null) 'errorMaxLines: "$errorMaxLines"',
      if (floatingLabelBehavior != null) 'floatingLabelBehavior: $floatingLabelBehavior',
      if (floatingLabelAlignment != null) 'floatingLabelAlignment: $floatingLabelAlignment',
      if (isDense ?? false) 'isDense: $isDense',
      if (contentPadding != null) 'contentPadding: $contentPadding',
      if (isCollapsed ?? false) 'isCollapsed: $isCollapsed',
      if (prefixIcon != null) 'prefixIcon: $prefixIcon',
      if (prefixIconColor != null) 'prefixIconColor: $prefixIconColor',
      if (prefix != null) 'prefix: $prefix',
      if (prefixText != null) 'prefixText: $prefixText',
      if (prefixStyle != null) 'prefixStyle: $prefixStyle',
      if (prefixIconConstraints != null) 'prefixIconConstraints: $prefixIconConstraints',
      if (suffixIcon != null) 'suffixIcon: $suffixIcon',
      if (suffixIconColor != null) 'suffixIconColor: $suffixIconColor',
      if (suffix != null) 'suffix: $suffix',
      if (suffixText != null) 'suffixText: $suffixText',
      if (suffixStyle != null) 'suffixStyle: $suffixStyle',
      if (suffixIconConstraints != null) 'suffixIconConstraints: $suffixIconConstraints',
      if (counter != null) 'counter: $counter',
      if (counterText != null) 'counterText: $counterText',
      if (counterStyle != null) 'counterStyle: $counterStyle',
      if (filled ?? false) 'filled: true',
      if (fillColor != null) 'fillColor: $fillColor',
      if (focusColor != null) 'focusColor: $focusColor',
      if (hoverColor != null) 'hoverColor: $hoverColor',
      if (errorBorder != null) 'errorBorder: $errorBorder',
      if (focusedBorder != null) 'focusedBorder: $focusedBorder',
      if (focusedErrorBorder != null) 'focusedErrorBorder: $focusedErrorBorder',
      if (disabledBorder != null) 'disabledBorder: $disabledBorder',
      if (enabledBorder != null) 'enabledBorder: $enabledBorder',
      if (border != null) 'border: $border',
      if (!enabled) 'enabled: false',
      if (semanticCounterText != null) 'semanticCounterText: $semanticCounterText',
      if (alignLabelWithHint != null) 'alignLabelWithHint: $alignLabelWithHint',
      if (constraints != null) 'constraints: $constraints',
    ];
    return 'InputDecoration(${description.join(', ')})';
  }
}

@immutable
class InputDecorationTheme with Diagnosticable {
  const InputDecorationTheme({
    this.labelStyle,
    this.floatingLabelStyle,
    this.helperStyle,
    this.helperMaxLines,
    this.hintStyle,
    this.hintFadeDuration,
    this.errorStyle,
    this.errorMaxLines,
    this.floatingLabelBehavior = FloatingLabelBehavior.auto,
    this.floatingLabelAlignment = FloatingLabelAlignment.start,
    this.isDense = false,
    this.contentPadding,
    this.isCollapsed = false,
    this.iconColor,
    this.prefixStyle,
    this.prefixIconColor,
    this.suffixStyle,
    this.suffixIconColor,
    this.counterStyle,
    this.filled = false,
    this.fillColor,
    this.activeIndicatorBorder,
    this.outlineBorder,
    this.focusColor,
    this.hoverColor,
    this.errorBorder,
    this.focusedBorder,
    this.focusedErrorBorder,
    this.disabledBorder,
    this.enabledBorder,
    this.border,
    this.alignLabelWithHint = false,
    this.constraints,
  });

  final TextStyle? labelStyle;

  final TextStyle? floatingLabelStyle;

  final TextStyle? helperStyle;

  final int? helperMaxLines;

  final TextStyle? hintStyle;

  final Duration? hintFadeDuration;

  final TextStyle? errorStyle;

  final int? errorMaxLines;

  final FloatingLabelBehavior floatingLabelBehavior;

  final FloatingLabelAlignment floatingLabelAlignment;

  final bool isDense;

  final EdgeInsetsGeometry? contentPadding;

  final bool isCollapsed;

  final Color? iconColor;

  final TextStyle? prefixStyle;

  final Color? prefixIconColor;

  final TextStyle? suffixStyle;

  final Color? suffixIconColor;

  final TextStyle? counterStyle;

  final bool filled;

  final Color? fillColor;

  final BorderSide? outlineBorder;

  final BorderSide? activeIndicatorBorder;

  final Color? focusColor;

  final Color? hoverColor;

  final InputBorder? errorBorder;

  final InputBorder? focusedBorder;

  final InputBorder? focusedErrorBorder;

  final InputBorder? disabledBorder;

  final InputBorder? enabledBorder;

  final InputBorder? border;

  final bool alignLabelWithHint;

  final BoxConstraints? constraints;

  InputDecorationTheme copyWith({
    TextStyle? labelStyle,
    TextStyle? floatingLabelStyle,
    TextStyle? helperStyle,
    int? helperMaxLines,
    TextStyle? hintStyle,
    Duration? hintFadeDuration,
    TextStyle? errorStyle,
    int? errorMaxLines,
    FloatingLabelBehavior? floatingLabelBehavior,
    FloatingLabelAlignment? floatingLabelAlignment,
    bool? isDense,
    EdgeInsetsGeometry? contentPadding,
    bool? isCollapsed,
    Color? iconColor,
    TextStyle? prefixStyle,
    Color? prefixIconColor,
    TextStyle? suffixStyle,
    Color? suffixIconColor,
    TextStyle? counterStyle,
    bool? filled,
    Color? fillColor,
    BorderSide? activeIndicatorBorder,
    BorderSide? outlineBorder,
    Color? focusColor,
    Color? hoverColor,
    InputBorder? errorBorder,
    InputBorder? focusedBorder,
    InputBorder? focusedErrorBorder,
    InputBorder? disabledBorder,
    InputBorder? enabledBorder,
    InputBorder? border,
    bool? alignLabelWithHint,
    BoxConstraints? constraints,
  }) {
    return InputDecorationTheme(
      labelStyle: labelStyle ?? this.labelStyle,
      floatingLabelStyle: floatingLabelStyle ?? this.floatingLabelStyle,
      helperStyle: helperStyle ?? this.helperStyle,
      helperMaxLines: helperMaxLines ?? this.helperMaxLines,
      hintStyle: hintStyle ?? this.hintStyle,
      hintFadeDuration: hintFadeDuration ?? this.hintFadeDuration,
      errorStyle: errorStyle ?? this.errorStyle,
      errorMaxLines: errorMaxLines ?? this.errorMaxLines,
      floatingLabelBehavior: floatingLabelBehavior ?? this.floatingLabelBehavior,
      floatingLabelAlignment: floatingLabelAlignment ?? this.floatingLabelAlignment,
      isDense: isDense ?? this.isDense,
      contentPadding: contentPadding ?? this.contentPadding,
      iconColor: iconColor,
      isCollapsed: isCollapsed ?? this.isCollapsed,
      prefixStyle: prefixStyle ?? this.prefixStyle,
      prefixIconColor: prefixIconColor ?? this.prefixIconColor,
      suffixStyle: suffixStyle ?? this.suffixStyle,
      suffixIconColor: suffixIconColor ?? this.suffixIconColor,
      counterStyle: counterStyle ?? this.counterStyle,
      filled: filled ?? this.filled,
      fillColor: fillColor ?? this.fillColor,
      activeIndicatorBorder: activeIndicatorBorder ?? this.activeIndicatorBorder,
      outlineBorder: outlineBorder ?? this.outlineBorder,
      focusColor: focusColor ?? this.focusColor,
      hoverColor: hoverColor ?? this.hoverColor,
      errorBorder: errorBorder ?? this.errorBorder,
      focusedBorder: focusedBorder ?? this.focusedBorder,
      focusedErrorBorder: focusedErrorBorder ?? this.focusedErrorBorder,
      disabledBorder: disabledBorder ?? this.disabledBorder,
      enabledBorder: enabledBorder ?? this.enabledBorder,
      border: border ?? this.border,
      alignLabelWithHint: alignLabelWithHint ?? this.alignLabelWithHint,
      constraints: constraints ?? this.constraints,
    );
  }

  InputDecorationTheme merge(InputDecorationTheme? inputDecorationTheme) {
    if (inputDecorationTheme == null) {
      return this;
    }
    return copyWith(
      labelStyle: labelStyle ?? inputDecorationTheme.labelStyle,
      floatingLabelStyle: floatingLabelStyle ?? inputDecorationTheme.floatingLabelStyle,
      helperStyle: helperStyle ?? inputDecorationTheme.helperStyle,
      helperMaxLines: helperMaxLines ?? inputDecorationTheme.helperMaxLines,
      hintStyle: hintStyle ?? inputDecorationTheme.hintStyle,
      hintFadeDuration: hintFadeDuration ?? inputDecorationTheme.hintFadeDuration,
      errorStyle: errorStyle ?? inputDecorationTheme.errorStyle,
      errorMaxLines: errorMaxLines ?? inputDecorationTheme.errorMaxLines,
      contentPadding: contentPadding ?? inputDecorationTheme.contentPadding,
      iconColor: iconColor ?? inputDecorationTheme.iconColor,
      prefixStyle: prefixStyle ?? inputDecorationTheme.prefixStyle,
      prefixIconColor: prefixIconColor ?? inputDecorationTheme.prefixIconColor,
      suffixStyle: suffixStyle ?? inputDecorationTheme.suffixStyle,
      suffixIconColor: suffixIconColor ?? inputDecorationTheme.suffixIconColor,
      counterStyle: counterStyle ?? inputDecorationTheme.counterStyle,
      fillColor: fillColor ?? inputDecorationTheme.fillColor,
      activeIndicatorBorder: activeIndicatorBorder ?? inputDecorationTheme.activeIndicatorBorder,
      outlineBorder: outlineBorder ?? inputDecorationTheme.outlineBorder,
      focusColor: focusColor ?? inputDecorationTheme.focusColor,
      hoverColor: hoverColor ?? inputDecorationTheme.hoverColor,
      errorBorder: errorBorder ?? inputDecorationTheme.errorBorder,
      focusedBorder: focusedBorder ?? inputDecorationTheme.focusedBorder,
      focusedErrorBorder: focusedErrorBorder ?? inputDecorationTheme.focusedErrorBorder,
      disabledBorder: disabledBorder ?? inputDecorationTheme.disabledBorder,
      enabledBorder: enabledBorder ?? inputDecorationTheme.enabledBorder,
      border: border ?? inputDecorationTheme.border,
      constraints: constraints ?? inputDecorationTheme.constraints,
    );
  }

  @override
  int get hashCode => Object.hash(
    labelStyle,
    floatingLabelStyle,
    helperStyle,
    helperMaxLines,
    hintStyle,
    errorStyle,
    errorMaxLines,
    floatingLabelBehavior,
    floatingLabelAlignment,
    isDense,
    contentPadding,
    isCollapsed,
    iconColor,
    prefixStyle,
    prefixIconColor,
    suffixStyle,
    suffixIconColor,
    counterStyle,
    filled,
    Object.hash(
      fillColor,
      activeIndicatorBorder,
      outlineBorder,
      focusColor,
      hoverColor,
      errorBorder,
      focusedBorder,
      focusedErrorBorder,
      disabledBorder,
      enabledBorder,
      border,
      alignLabelWithHint,
      constraints,
      hintFadeDuration,
    ),
  );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is InputDecorationTheme
        && other.labelStyle == labelStyle
        && other.floatingLabelStyle == floatingLabelStyle
        && other.helperStyle == helperStyle
        && other.helperMaxLines == helperMaxLines
        && other.hintStyle == hintStyle
        && other.hintFadeDuration == hintFadeDuration
        && other.errorStyle == errorStyle
        && other.errorMaxLines == errorMaxLines
        && other.isDense == isDense
        && other.contentPadding == contentPadding
        && other.isCollapsed == isCollapsed
        && other.iconColor == iconColor
        && other.prefixStyle == prefixStyle
        && other.prefixIconColor == prefixIconColor
        && other.suffixStyle == suffixStyle
        && other.suffixIconColor == suffixIconColor
        && other.counterStyle == counterStyle
        && other.floatingLabelBehavior == floatingLabelBehavior
        && other.floatingLabelAlignment == floatingLabelAlignment
        && other.filled == filled
        && other.fillColor == fillColor
        && other.activeIndicatorBorder == activeIndicatorBorder
        && other.outlineBorder == outlineBorder
        && other.focusColor == focusColor
        && other.hoverColor == hoverColor
        && other.errorBorder == errorBorder
        && other.focusedBorder == focusedBorder
        && other.focusedErrorBorder == focusedErrorBorder
        && other.disabledBorder == disabledBorder
        && other.enabledBorder == enabledBorder
        && other.border == border
        && other.alignLabelWithHint == alignLabelWithHint
        && other.constraints == constraints
        && other.disabledBorder == disabledBorder;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    const InputDecorationTheme defaultTheme = InputDecorationTheme();
    properties.add(DiagnosticsProperty<TextStyle>('labelStyle', labelStyle, defaultValue: defaultTheme.labelStyle));
    properties.add(DiagnosticsProperty<TextStyle>('floatingLabelStyle', floatingLabelStyle, defaultValue: defaultTheme.floatingLabelStyle));
    properties.add(DiagnosticsProperty<TextStyle>('helperStyle', helperStyle, defaultValue: defaultTheme.helperStyle));
    properties.add(IntProperty('helperMaxLines', helperMaxLines, defaultValue: defaultTheme.helperMaxLines));
    properties.add(DiagnosticsProperty<TextStyle>('hintStyle', hintStyle, defaultValue: defaultTheme.hintStyle));
    properties.add(DiagnosticsProperty<Duration>('hintFadeDuration', hintFadeDuration, defaultValue: defaultTheme.hintFadeDuration));
    properties.add(DiagnosticsProperty<TextStyle>('errorStyle', errorStyle, defaultValue: defaultTheme.errorStyle));
    properties.add(IntProperty('errorMaxLines', errorMaxLines, defaultValue: defaultTheme.errorMaxLines));
    properties.add(DiagnosticsProperty<FloatingLabelBehavior>('floatingLabelBehavior', floatingLabelBehavior, defaultValue: defaultTheme.floatingLabelBehavior));
    properties.add(DiagnosticsProperty<FloatingLabelAlignment>('floatingLabelAlignment', floatingLabelAlignment, defaultValue: defaultTheme.floatingLabelAlignment));
    properties.add(DiagnosticsProperty<bool>('isDense', isDense, defaultValue: defaultTheme.isDense));
    properties.add(DiagnosticsProperty<EdgeInsetsGeometry>('contentPadding', contentPadding, defaultValue: defaultTheme.contentPadding));
    properties.add(DiagnosticsProperty<bool>('isCollapsed', isCollapsed, defaultValue: defaultTheme.isCollapsed));
    properties.add(DiagnosticsProperty<Color>('iconColor', iconColor, defaultValue: defaultTheme.iconColor));
    properties.add(DiagnosticsProperty<Color>('prefixIconColor', prefixIconColor, defaultValue: defaultTheme.prefixIconColor));
    properties.add(DiagnosticsProperty<TextStyle>('prefixStyle', prefixStyle, defaultValue: defaultTheme.prefixStyle));
    properties.add(DiagnosticsProperty<Color>('suffixIconColor', suffixIconColor, defaultValue: defaultTheme.suffixIconColor));
    properties.add(DiagnosticsProperty<TextStyle>('suffixStyle', suffixStyle, defaultValue: defaultTheme.suffixStyle));
    properties.add(DiagnosticsProperty<TextStyle>('counterStyle', counterStyle, defaultValue: defaultTheme.counterStyle));
    properties.add(DiagnosticsProperty<bool>('filled', filled, defaultValue: defaultTheme.filled));
    properties.add(ColorProperty('fillColor', fillColor, defaultValue: defaultTheme.fillColor));
    properties.add(DiagnosticsProperty<BorderSide>('activeIndicatorBorder', activeIndicatorBorder, defaultValue: defaultTheme.activeIndicatorBorder));
    properties.add(DiagnosticsProperty<BorderSide>('outlineBorder', outlineBorder, defaultValue: defaultTheme.outlineBorder));
    properties.add(ColorProperty('focusColor', focusColor, defaultValue: defaultTheme.focusColor));
    properties.add(ColorProperty('hoverColor', hoverColor, defaultValue: defaultTheme.hoverColor));
    properties.add(DiagnosticsProperty<InputBorder>('errorBorder', errorBorder, defaultValue: defaultTheme.errorBorder));
    properties.add(DiagnosticsProperty<InputBorder>('focusedBorder', focusedBorder, defaultValue: defaultTheme.focusedErrorBorder));
    properties.add(DiagnosticsProperty<InputBorder>('focusedErrorBorder', focusedErrorBorder, defaultValue: defaultTheme.focusedErrorBorder));
    properties.add(DiagnosticsProperty<InputBorder>('disabledBorder', disabledBorder, defaultValue: defaultTheme.disabledBorder));
    properties.add(DiagnosticsProperty<InputBorder>('enabledBorder', enabledBorder, defaultValue: defaultTheme.enabledBorder));
    properties.add(DiagnosticsProperty<InputBorder>('border', border, defaultValue: defaultTheme.border));
    properties.add(DiagnosticsProperty<bool>('alignLabelWithHint', alignLabelWithHint, defaultValue: defaultTheme.alignLabelWithHint));
    properties.add(DiagnosticsProperty<BoxConstraints>('constraints', constraints, defaultValue: defaultTheme.constraints));
  }
}

class _InputDecoratorDefaultsM2 extends InputDecorationTheme {
  const _InputDecoratorDefaultsM2(this.context)
      : super();

  final BuildContext context;

  @override
  TextStyle? get hintStyle => MaterialStateTextStyle.resolveWith((Set<MaterialState> states) {
    if (states.contains(MaterialState.disabled)) {
      return TextStyle(color: Theme.of(context).disabledColor);
    }
    return TextStyle(color: Theme.of(context).hintColor);
  });

  @override
  TextStyle? get labelStyle => MaterialStateTextStyle.resolveWith((Set<MaterialState> states) {
    if (states.contains(MaterialState.disabled)) {
      return TextStyle(color: Theme.of(context).disabledColor);
    }
    return TextStyle(color: Theme.of(context).hintColor);
  });

  @override
  TextStyle? get floatingLabelStyle => MaterialStateTextStyle.resolveWith((Set<MaterialState> states) {
    if (states.contains(MaterialState.disabled)) {
      return TextStyle(color: Theme.of(context).disabledColor);
    }
    if (states.contains(MaterialState.error)) {
      return TextStyle(color: Theme.of(context).colorScheme.error);
    }
    if (states.contains(MaterialState.focused)) {
      return TextStyle(color: Theme.of(context).colorScheme.primary);
    }
    return TextStyle(color: Theme.of(context).hintColor);
  });

  @override
  TextStyle? get helperStyle => MaterialStateTextStyle.resolveWith((Set<MaterialState> states) {
    final ThemeData themeData= Theme.of(context);
    if (states.contains(MaterialState.disabled)) {
      return themeData.textTheme.bodySmall!.copyWith(color: Colors.transparent);
    }

    return themeData.textTheme.bodySmall!.copyWith(color: themeData.hintColor);
  });

  @override
  TextStyle? get errorStyle => MaterialStateTextStyle.resolveWith((Set<MaterialState> states) {
    final ThemeData themeData= Theme.of(context);
    if (states.contains(MaterialState.disabled)) {
      return themeData.textTheme.bodySmall!.copyWith(color: Colors.transparent);
    }
    return themeData.textTheme.bodySmall!.copyWith(color: themeData.colorScheme.error);
  });

  @override
  Color? get fillColor => MaterialStateColor.resolveWith((Set<MaterialState> states) {
    if (states.contains(MaterialState.disabled)) {
      // dark theme: 5% white
      // light theme: 2% black
      switch (Theme.of(context).brightness) {
        case Brightness.dark:
          return const Color(0x0DFFFFFF);
        case Brightness.light:
          return const Color(0x05000000) ;
      }
    }
    // dark theme: 10% white
    // light theme: 4% black
    switch (Theme.of(context).brightness) {
      case Brightness.dark: return const Color(0x1AFFFFFF);
      case Brightness.light:return const Color(0x0A000000) ;
    }
  });

  @override
  Color? get iconColor => MaterialStateColor.resolveWith((Set<MaterialState> states) {
    if (states.contains(MaterialState.disabled) && !states.contains(MaterialState.focused)) {
      return Theme.of(context).disabledColor;
    }
    if (states.contains(MaterialState.focused)) {
      return Theme.of(context).colorScheme.primary;
    }
    switch (Theme.of(context).brightness) {
      case Brightness.dark:
        return Colors.white70;
      case Brightness.light:
        return Colors.black45;
    }
  });

  @override
  Color? get prefixIconColor => MaterialStateColor.resolveWith((Set<MaterialState> states) {
    if (states.contains(MaterialState.disabled) && !states.contains(MaterialState.focused)) {
      return Theme.of(context).disabledColor;
    }
    if (states.contains(MaterialState.focused)) {
      return Theme.of(context).colorScheme.primary;
    }
    switch (Theme.of(context).brightness) {
      case Brightness.dark:
        return Colors.white70;
      case Brightness.light:
        return Colors.black45;
    }
  });

  @override
  Color? get suffixIconColor => MaterialStateColor.resolveWith((Set<MaterialState> states) {
    if (states.contains(MaterialState.disabled) && !states.contains(MaterialState.focused)) {
      return Theme.of(context).disabledColor;
    }
    if (states.contains(MaterialState.focused)) {
      return Theme.of(context).colorScheme.primary;
    }
    switch (Theme.of(context).brightness) {
      case Brightness.dark:
        return Colors.white70;
      case Brightness.light:
        return Colors.black45;
    }
  });
}

// BEGIN GENERATED TOKEN PROPERTIES - InputDecorator

// Do not edit by hand. The code between the "BEGIN GENERATED" and
// "END GENERATED" comments are generated from data in the Material
// Design token database by the script:
//   dev/tools/gen_defaults/bin/gen_defaults.dart.

class _InputDecoratorDefaultsM3 extends InputDecorationTheme {
   _InputDecoratorDefaultsM3(this.context)
    : super();

  final BuildContext context;

  late final ColorScheme _colors = Theme.of(context).colorScheme;
  late final TextTheme _textTheme = Theme.of(context).textTheme;

  @override
  TextStyle? get hintStyle => MaterialStateTextStyle.resolveWith((Set<MaterialState> states) {
    if (states.contains(MaterialState.disabled)) {
      return TextStyle(color: Theme.of(context).disabledColor);
    }
    return TextStyle(color: Theme.of(context).hintColor);
  });

  @override
  Color? get fillColor => MaterialStateColor.resolveWith((Set<MaterialState> states) {
    if (states.contains(MaterialState.disabled)) {
      return _colors.onSurface.withOpacity(0.04);
    }
    return _colors.surfaceVariant;
  });

  @override
  BorderSide? get activeIndicatorBorder => MaterialStateBorderSide.resolveWith((Set<MaterialState> states) {
    if (states.contains(MaterialState.disabled)) {
      return BorderSide(color: _colors.onSurface.withOpacity(0.38));
    }
    if (states.contains(MaterialState.error)) {
      if (states.contains(MaterialState.hovered)) {
        return BorderSide(color: _colors.onErrorContainer);
      }
      if (states.contains(MaterialState.focused)) {
        return BorderSide(color: _colors.error, width: 2.0);
      }
      return BorderSide(color: _colors.error);
    }
    if (states.contains(MaterialState.hovered)) {
      return BorderSide(color: _colors.onSurface);
    }
    if (states.contains(MaterialState.focused)) {
      return BorderSide(color: _colors.primary, width: 2.0);
    }
    return BorderSide(color: _colors.onSurfaceVariant);
    });

  @override
  BorderSide? get outlineBorder => MaterialStateBorderSide.resolveWith((Set<MaterialState> states) {
    if (states.contains(MaterialState.disabled)) {
      return BorderSide(color: _colors.onSurface.withOpacity(0.12));
    }
    if (states.contains(MaterialState.error)) {
      if (states.contains(MaterialState.hovered)) {
        return BorderSide(color: _colors.onErrorContainer);
      }
      if (states.contains(MaterialState.focused)) {
        return BorderSide(color: _colors.error, width: 2.0);
      }
      return BorderSide(color: _colors.error);
    }
    if (states.contains(MaterialState.hovered)) {
      return BorderSide(color: _colors.onSurface);
    }
    if (states.contains(MaterialState.focused)) {
      return BorderSide(color: _colors.primary, width: 2.0);
    }
    return BorderSide(color: _colors.outline);
  });

  @override
  Color? get iconColor => _colors.onSurfaceVariant;

  @override
  Color? get prefixIconColor => MaterialStateColor.resolveWith((Set<MaterialState> states) {
    return _colors.onSurfaceVariant;
  });

  @override
  Color? get suffixIconColor => MaterialStateColor.resolveWith((Set<MaterialState> states) {
    if (states.contains(MaterialState.disabled)) {
      return _colors.onSurface.withOpacity(0.38);
    }
    if (states.contains(MaterialState.error)) {
      return _colors.error;
    }
    return _colors.onSurfaceVariant;
  });

  @override
  TextStyle? get labelStyle => MaterialStateTextStyle.resolveWith((Set<MaterialState> states) {
    final TextStyle textStyle = _textTheme.bodyLarge ?? const TextStyle();
    if (states.contains(MaterialState.disabled)) {
      return textStyle.copyWith(color: _colors.onSurface.withOpacity(0.38));
    }
    if (states.contains(MaterialState.error)) {
      if (states.contains(MaterialState.hovered)) {
        return textStyle.copyWith(color: _colors.onErrorContainer);
      }
      if (states.contains(MaterialState.focused)) {
        return textStyle.copyWith(color: _colors.error);
      }
      return textStyle.copyWith(color: _colors.error);
    }
    if (states.contains(MaterialState.hovered)) {
      return textStyle.copyWith(color: _colors.onSurfaceVariant);
    }
    if (states.contains(MaterialState.focused)) {
      return textStyle.copyWith(color: _colors.primary);
    }
    return textStyle.copyWith(color: _colors.onSurfaceVariant);
  });

  @override
  TextStyle? get floatingLabelStyle => MaterialStateTextStyle.resolveWith((Set<MaterialState> states) {
    final TextStyle textStyle = _textTheme.bodyLarge ?? const TextStyle();
    if (states.contains(MaterialState.disabled)) {
      return textStyle.copyWith(color: _colors.onSurface.withOpacity(0.38));
    }
    if (states.contains(MaterialState.error)) {
      if (states.contains(MaterialState.hovered)) {
        return textStyle.copyWith(color: _colors.onErrorContainer);
      }
      if (states.contains(MaterialState.focused)) {
        return textStyle.copyWith(color: _colors.error);
      }
      return textStyle.copyWith(color: _colors.error);
    }
    if (states.contains(MaterialState.hovered)) {
      return textStyle.copyWith(color: _colors.onSurfaceVariant);
    }
    if (states.contains(MaterialState.focused)) {
      return textStyle.copyWith(color: _colors.primary);
    }
    return textStyle.copyWith(color: _colors.onSurfaceVariant);
  });

  @override
  TextStyle? get helperStyle => MaterialStateTextStyle.resolveWith((Set<MaterialState> states) {
    final TextStyle textStyle = _textTheme.bodySmall ?? const TextStyle();
    if (states.contains(MaterialState.disabled)) {
      return textStyle.copyWith(color: _colors.onSurface.withOpacity(0.38));
    }
    return textStyle.copyWith(color: _colors.onSurfaceVariant);
  });

  @override
  TextStyle? get errorStyle => MaterialStateTextStyle.resolveWith((Set<MaterialState> states) {
    final TextStyle textStyle = _textTheme.bodySmall ?? const TextStyle();
    return textStyle.copyWith(color: _colors.error);
  });
}

// END GENERATED TOKEN PROPERTIES - InputDecorator