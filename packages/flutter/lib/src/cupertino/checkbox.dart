
import 'package:flutter/widgets.dart';

import 'colors.dart';
import 'constants.dart';
import 'toggleable.dart';

// Examples can assume:
// bool _throwShotAway = false;
// late StateSetter setState;

// The relative values needed to transform a color to it's equivilant focus
// outline color.
const double _kCupertinoFocusColorOpacity = 0.80;
const double _kCupertinoFocusColorBrightness = 0.69;
const double _kCupertinoFocusColorSaturation = 0.835;

class CupertinoCheckbox extends StatefulWidget {
  const CupertinoCheckbox({
    super.key,
    required this.value,
    this.tristate = false,
    required this.onChanged,
    this.activeColor,
    this.inactiveColor,
    this.checkColor,
    this.focusColor,
    this.focusNode,
    this.autofocus = false,
    this.side,
    this.shape,
  }) : assert(tristate || value != null);

  final bool? value;

  final ValueChanged<bool?>? onChanged;

  final Color? activeColor;

  final Color? inactiveColor;

  final Color? checkColor;

  final bool tristate;

  final Color? focusColor;

  final FocusNode? focusNode;

  final bool autofocus;

  final BorderSide? side;

  final OutlinedBorder? shape;

  static const double width = 18.0;

  @override
  State<CupertinoCheckbox> createState() => _CupertinoCheckboxState();
}

class _CupertinoCheckboxState extends State<CupertinoCheckbox> with TickerProviderStateMixin, ToggleableStateMixin {
  final _CheckboxPainter _painter = _CheckboxPainter();
  bool? _previousValue;

  bool focused = false;

  @override
  void initState() {
    super.initState();
    _previousValue = widget.value;
  }

  @override
  void didUpdateWidget(CupertinoCheckbox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _previousValue = oldWidget.value;
    }
  }

  @override
  void dispose() {
    _painter.dispose();
    super.dispose();
  }

  @override
  ValueChanged<bool?>? get onChanged => widget.onChanged;

  @override
  bool get tristate => widget.tristate;

  @override
  bool? get value => widget.value;

  void onFocusChange(bool value) {
    if (focused != value) {
      focused = value;
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color effectiveActiveColor = widget.activeColor
      ?? CupertinoColors.activeBlue;
    final Color? inactiveColor = widget.inactiveColor;
    final Color effectiveInactiveColor = inactiveColor
      ?? CupertinoColors.inactiveGray;

    final Color effectiveFocusOverlayColor = widget.focusColor
      ?? HSLColor
          .fromColor(effectiveActiveColor.withOpacity(_kCupertinoFocusColorOpacity))
          .withLightness(_kCupertinoFocusColorBrightness)
          .withSaturation(_kCupertinoFocusColorSaturation)
          .toColor();

    final Color effectiveCheckColor = widget.checkColor
      ?? CupertinoColors.white;

    return Semantics(
      checked: widget.value ?? false,
      mixed: widget.tristate ? widget.value == null : null,
      child: buildToggleable(
        focusNode: widget.focusNode,
        autofocus: widget.autofocus,
        onFocusChange: onFocusChange,
        size: const Size.square(kMinInteractiveDimensionCupertino),
        painter: _painter
          ..focusColor = effectiveFocusOverlayColor
          ..isFocused = focused
          ..downPosition = downPosition
          ..activeColor = effectiveActiveColor
          ..inactiveColor = effectiveInactiveColor
          ..checkColor = effectiveCheckColor
          ..value = value
          ..previousValue = _previousValue
          ..isActive = widget.onChanged != null
          ..shape = widget.shape ?? RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4.0),
          )
          ..side = widget.side,
      ),
    );
  }
}

class _CheckboxPainter extends ToggleablePainter {
  Color get checkColor => _checkColor!;
  Color? _checkColor;
  set checkColor(Color value) {
    if (_checkColor == value) {
      return;
    }
    _checkColor = value;
    notifyListeners();
  }

  bool? get value => _value;
  bool? _value;
  set value(bool? value) {
    if (_value == value) {
      return;
    }
    _value = value;
    notifyListeners();
  }

  bool? get previousValue => _previousValue;
  bool? _previousValue;
  set previousValue(bool? value) {
    if (_previousValue == value) {
      return;
    }
    _previousValue = value;
    notifyListeners();
  }

  OutlinedBorder get shape => _shape!;
  OutlinedBorder? _shape;
  set shape(OutlinedBorder value) {
    if (_shape == value) {
      return;
    }
    _shape = value;
    notifyListeners();
  }

  BorderSide? get side => _side;
  BorderSide? _side;
  set side(BorderSide? value) {
    if (_side == value) {
      return;
    }
    _side = value;
    notifyListeners();
  }

  Rect _outerRectAt(Offset origin) {
    const double size = CupertinoCheckbox.width;
    final Rect rect = Rect.fromLTWH(origin.dx, origin.dy, size, size);
    return rect;
  }

  // The checkbox's border color if value == false, or its fill color when
  // value == true or null.
  Color _colorAt(bool value) {
    return value && isActive ? activeColor : inactiveColor;
  }

  // White stroke used to paint the check and dash.
  Paint _createStrokePaint() {
    return Paint()
      ..color = checkColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
  }

  void _drawBox(Canvas canvas, Rect outer, Paint paint, BorderSide? side, bool fill) {
    if (fill) {
      canvas.drawPath(shape.getOuterPath(outer), paint);
    }
    if (side != null) {
      shape.copyWith(side: side).paint(canvas, outer);
    }
  }

  void _drawCheck(Canvas canvas, Offset origin, Paint paint) {
    final Path path = Path();
    // The ratios for the offsets below were found from looking at the checkbox
    // examples on in the HIG docs. The distance from the needed point to the
    // edge was measured, then devided by the total width.
    const Offset start = Offset(CupertinoCheckbox.width * 0.25, CupertinoCheckbox.width * 0.52);
    const Offset mid = Offset(CupertinoCheckbox.width * 0.46, CupertinoCheckbox.width * 0.75);
    const Offset end = Offset(CupertinoCheckbox.width * 0.72, CupertinoCheckbox.width * 0.29);
    path.moveTo(origin.dx + start.dx, origin.dy + start.dy);
    path.lineTo(origin.dx + mid.dx, origin.dy + mid.dy);
    canvas.drawPath(path, paint);
    path.moveTo(origin.dx + mid.dx, origin.dy + mid.dy);
    path.lineTo(origin.dx + end.dx, origin.dy + end.dy);
    canvas.drawPath(path, paint);
  }

  void _drawDash(Canvas canvas, Offset origin, Paint paint) {
    // From measuring the checkbox example in the HIG docs, the dash was found
    // to be half the total width, centered in the middle.
    const Offset start = Offset(CupertinoCheckbox.width * 0.25, CupertinoCheckbox.width * 0.5);
    const Offset end = Offset(CupertinoCheckbox.width * 0.75, CupertinoCheckbox.width * 0.5);
    canvas.drawLine(origin + start, origin + end, paint);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final Paint strokePaint = _createStrokePaint();
    final Offset origin = size / 2.0 - const Size.square(CupertinoCheckbox.width) / 2.0 as Offset;

    final Rect outer = _outerRectAt(origin);
    final Paint paint = Paint()..color = _colorAt(value ?? true);

    if (value == false) {

      final BorderSide border = side ?? BorderSide(color: paint.color);
      _drawBox(canvas, outer, paint, border, false);
    } else {

      _drawBox(canvas, outer, paint, side, true);
      if (value ?? false) {
        _drawCheck(canvas, origin, strokePaint);
      } else {
        _drawDash(canvas, origin, strokePaint);
      }
    }

    if (isFocused) {
      final Rect focusOuter = outer.inflate(1);

      final Paint borderPaint = Paint()
        ..color = focusColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5;

      _drawBox(canvas, focusOuter, borderPaint, side, true);
    }
  }
}