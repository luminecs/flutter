import 'dart:ui' as ui show ViewPadding, lerpDouble;

import 'package:flutter/foundation.dart';

import 'basic_types.dart';

@immutable
abstract class EdgeInsetsGeometry {
  const EdgeInsetsGeometry();

  double get _bottom;
  double get _end;
  double get _left;
  double get _right;
  double get _start;
  double get _top;

  static const EdgeInsetsGeometry infinity = _MixedEdgeInsets.fromLRSETB(
    double.infinity,
    double.infinity,
    double.infinity,
    double.infinity,
    double.infinity,
    double.infinity,
  );

  bool get isNonNegative {
    return _left >= 0.0
        && _right >= 0.0
        && _start >= 0.0
        && _end >= 0.0
        && _top >= 0.0
        && _bottom >= 0.0;
  }

  double get horizontal => _left + _right + _start + _end;

  double get vertical => _top + _bottom;

  double along(Axis axis) {
    switch (axis) {
      case Axis.horizontal:
        return horizontal;
      case Axis.vertical:
        return vertical;
    }
  }

  Size get collapsedSize => Size(horizontal, vertical);

  EdgeInsetsGeometry get flipped => _MixedEdgeInsets.fromLRSETB(_right, _left, _end, _start, _bottom, _top);

  Size inflateSize(Size size) {
    return Size(size.width + horizontal, size.height + vertical);
  }

  Size deflateSize(Size size) {
    return Size(size.width - horizontal, size.height - vertical);
  }

  EdgeInsetsGeometry subtract(EdgeInsetsGeometry other) {
    return _MixedEdgeInsets.fromLRSETB(
      _left - other._left,
      _right - other._right,
      _start - other._start,
      _end - other._end,
      _top - other._top,
      _bottom - other._bottom,
    );
  }

  EdgeInsetsGeometry add(EdgeInsetsGeometry other) {
    return _MixedEdgeInsets.fromLRSETB(
      _left + other._left,
      _right + other._right,
      _start + other._start,
      _end + other._end,
      _top + other._top,
      _bottom + other._bottom,
    );
  }

  EdgeInsetsGeometry clamp(EdgeInsetsGeometry min, EdgeInsetsGeometry max) {
    return _MixedEdgeInsets.fromLRSETB(
      clampDouble(_left, min._left, max._left),
      clampDouble(_right, min._right, max._right),
      clampDouble(_start, min._start, max._start),
      clampDouble(_end, min._end, max._end),
      clampDouble(_top, min._top, max._top),
      clampDouble(_bottom, min._bottom, max._bottom),
    );
  }

  EdgeInsetsGeometry operator -();

  EdgeInsetsGeometry operator *(double other);

  EdgeInsetsGeometry operator /(double other);

  EdgeInsetsGeometry operator ~/(double other);

  EdgeInsetsGeometry operator %(double other);

  static EdgeInsetsGeometry? lerp(EdgeInsetsGeometry? a, EdgeInsetsGeometry? b, double t) {
    if (identical(a, b)) {
      return a;
    }
    if (a == null) {
      return b! * t;
    }
    if (b == null) {
      return a * (1.0 - t);
    }
    if (a is EdgeInsets && b is EdgeInsets) {
      return EdgeInsets.lerp(a, b, t);
    }
    if (a is EdgeInsetsDirectional && b is EdgeInsetsDirectional) {
      return EdgeInsetsDirectional.lerp(a, b, t);
    }
    return _MixedEdgeInsets.fromLRSETB(
      ui.lerpDouble(a._left, b._left, t)!,
      ui.lerpDouble(a._right, b._right, t)!,
      ui.lerpDouble(a._start, b._start, t)!,
      ui.lerpDouble(a._end, b._end, t)!,
      ui.lerpDouble(a._top, b._top, t)!,
      ui.lerpDouble(a._bottom, b._bottom, t)!,
    );
  }

  EdgeInsets resolve(TextDirection? direction);

  @override
  String toString() {
    if (_start == 0.0 && _end == 0.0) {
      if (_left == 0.0 && _right == 0.0 && _top == 0.0 && _bottom == 0.0) {
        return 'EdgeInsets.zero';
      }
      if (_left == _right && _right == _top && _top == _bottom) {
        return 'EdgeInsets.all(${_left.toStringAsFixed(1)})';
      }
      return 'EdgeInsets(${_left.toStringAsFixed(1)}, '
                        '${_top.toStringAsFixed(1)}, '
                        '${_right.toStringAsFixed(1)}, '
                        '${_bottom.toStringAsFixed(1)})';
    }
    if (_left == 0.0 && _right == 0.0) {
      return 'EdgeInsetsDirectional(${_start.toStringAsFixed(1)}, '
                                   '${_top.toStringAsFixed(1)}, '
                                   '${_end.toStringAsFixed(1)}, '
                                   '${_bottom.toStringAsFixed(1)})';
    }
    return 'EdgeInsets(${_left.toStringAsFixed(1)}, '
                      '${_top.toStringAsFixed(1)}, '
                      '${_right.toStringAsFixed(1)}, '
                      '${_bottom.toStringAsFixed(1)})'
           ' + '
           'EdgeInsetsDirectional(${_start.toStringAsFixed(1)}, '
                                 '0.0, '
                                 '${_end.toStringAsFixed(1)}, '
                                 '0.0)';
  }

  @override
  bool operator ==(Object other) {
    return other is EdgeInsetsGeometry
        && other._left == _left
        && other._right == _right
        && other._start == _start
        && other._end == _end
        && other._top == _top
        && other._bottom == _bottom;
  }

  @override
  int get hashCode => Object.hash(_left, _right, _start, _end, _top, _bottom);
}

class EdgeInsets extends EdgeInsetsGeometry {
  const EdgeInsets.fromLTRB(this.left, this.top, this.right, this.bottom);

  const EdgeInsets.all(double value)
    : left = value,
      top = value,
      right = value,
      bottom = value;

  const EdgeInsets.only({
    this.left = 0.0,
    this.top = 0.0,
    this.right = 0.0,
    this.bottom = 0.0,
  });

  const EdgeInsets.symmetric({
    double vertical = 0.0,
    double horizontal = 0.0,
  }) : left = horizontal,
       top = vertical,
       right = horizontal,
       bottom = vertical;

  EdgeInsets.fromViewPadding(ui.ViewPadding padding, double devicePixelRatio)
    : left = padding.left / devicePixelRatio,
      top = padding.top / devicePixelRatio,
      right = padding.right / devicePixelRatio,
      bottom = padding.bottom / devicePixelRatio;

  @Deprecated(
    'Use EdgeInsets.fromViewPadding instead. '
    'This feature was deprecated after v3.8.0-14.0.pre.',
  )
  factory EdgeInsets.fromWindowPadding(ui.ViewPadding padding, double devicePixelRatio) = EdgeInsets.fromViewPadding;

  static const EdgeInsets zero = EdgeInsets.only();

  final double left;

  @override
  double get _left => left;

  final double top;

  @override
  double get _top => top;

  final double right;

  @override
  double get _right => right;

  final double bottom;

  @override
  double get _bottom => bottom;

  @override
  double get _start => 0.0;

  @override
  double get _end => 0.0;

  Offset get topLeft => Offset(left, top);

  Offset get topRight => Offset(-right, top);

  Offset get bottomLeft => Offset(left, -bottom);

  Offset get bottomRight => Offset(-right, -bottom);

  @override
  EdgeInsets get flipped => EdgeInsets.fromLTRB(right, bottom, left, top);

  Rect inflateRect(Rect rect) {
    return Rect.fromLTRB(rect.left - left, rect.top - top, rect.right + right, rect.bottom + bottom);
  }

  Rect deflateRect(Rect rect) {
    return Rect.fromLTRB(rect.left + left, rect.top + top, rect.right - right, rect.bottom - bottom);
  }

  @override
  EdgeInsetsGeometry subtract(EdgeInsetsGeometry other) {
    if (other is EdgeInsets) {
      return this - other;
    }
    return super.subtract(other);
  }

  @override
  EdgeInsetsGeometry add(EdgeInsetsGeometry other) {
    if (other is EdgeInsets) {
      return this + other;
    }
    return super.add(other);
  }

  @override
  EdgeInsetsGeometry clamp(EdgeInsetsGeometry min, EdgeInsetsGeometry max) {
    return EdgeInsets.fromLTRB(
      clampDouble(_left, min._left, max._left),
      clampDouble(_top, min._top, max._top),
      clampDouble(_right, min._right, max._right),
      clampDouble(_bottom, min._bottom, max._bottom),
    );
  }

  EdgeInsets operator -(EdgeInsets other) {
    return EdgeInsets.fromLTRB(
      left - other.left,
      top - other.top,
      right - other.right,
      bottom - other.bottom,
    );
  }

  EdgeInsets operator +(EdgeInsets other) {
    return EdgeInsets.fromLTRB(
      left + other.left,
      top + other.top,
      right + other.right,
      bottom + other.bottom,
    );
  }

  @override
  EdgeInsets operator -() {
    return EdgeInsets.fromLTRB(
      -left,
      -top,
      -right,
      -bottom,
    );
  }

  @override
  EdgeInsets operator *(double other) {
    return EdgeInsets.fromLTRB(
      left * other,
      top * other,
      right * other,
      bottom * other,
    );
  }

  @override
  EdgeInsets operator /(double other) {
    return EdgeInsets.fromLTRB(
      left / other,
      top / other,
      right / other,
      bottom / other,
    );
  }

  @override
  EdgeInsets operator ~/(double other) {
    return EdgeInsets.fromLTRB(
      (left ~/ other).toDouble(),
      (top ~/ other).toDouble(),
      (right ~/ other).toDouble(),
      (bottom ~/ other).toDouble(),
    );
  }

  @override
  EdgeInsets operator %(double other) {
    return EdgeInsets.fromLTRB(
      left % other,
      top % other,
      right % other,
      bottom % other,
    );
  }

  static EdgeInsets? lerp(EdgeInsets? a, EdgeInsets? b, double t) {
    if (identical(a, b)) {
      return a;
    }
    if (a == null) {
      return b! * t;
    }
    if (b == null) {
      return a * (1.0 - t);
    }
    return EdgeInsets.fromLTRB(
      ui.lerpDouble(a.left, b.left, t)!,
      ui.lerpDouble(a.top, b.top, t)!,
      ui.lerpDouble(a.right, b.right, t)!,
      ui.lerpDouble(a.bottom, b.bottom, t)!,
    );
  }

  @override
  EdgeInsets resolve(TextDirection? direction) => this;

  EdgeInsets copyWith({
    double? left,
    double? top,
    double? right,
    double? bottom,
  }) {
    return EdgeInsets.only(
      left: left ?? this.left,
      top: top ?? this.top,
      right: right ?? this.right,
      bottom: bottom ?? this.bottom,
    );
  }
}

class EdgeInsetsDirectional extends EdgeInsetsGeometry {
  const EdgeInsetsDirectional.fromSTEB(this.start, this.top, this.end, this.bottom);

  const EdgeInsetsDirectional.only({
    this.start = 0.0,
    this.top = 0.0,
    this.end = 0.0,
    this.bottom = 0.0,
  });

  const EdgeInsetsDirectional.symmetric({
    double horizontal = 0.0,
    double vertical = 0.0,
  })  : start = horizontal,
        end = horizontal,
        top = vertical,
        bottom = vertical;

  const EdgeInsetsDirectional.all(double value)
    : start = value,
      top = value,
      end = value,
      bottom = value;

  static const EdgeInsetsDirectional zero = EdgeInsetsDirectional.only();

  final double start;

  @override
  double get _start => start;

  final double top;

  @override
  double get _top => top;

  final double end;

  @override
  double get _end => end;

  final double bottom;

  @override
  double get _bottom => bottom;

  @override
  double get _left => 0.0;

  @override
  double get _right => 0.0;

  @override
  bool get isNonNegative => start >= 0.0 && top >= 0.0 && end >= 0.0 && bottom >= 0.0;

  @override
  EdgeInsetsDirectional get flipped => EdgeInsetsDirectional.fromSTEB(end, bottom, start, top);

  @override
  EdgeInsetsGeometry subtract(EdgeInsetsGeometry other) {
    if (other is EdgeInsetsDirectional) {
      return this - other;
    }
    return super.subtract(other);
  }

  @override
  EdgeInsetsGeometry add(EdgeInsetsGeometry other) {
    if (other is EdgeInsetsDirectional) {
      return this + other;
    }
    return super.add(other);
  }

  EdgeInsetsDirectional operator -(EdgeInsetsDirectional other) {
    return EdgeInsetsDirectional.fromSTEB(
      start - other.start,
      top - other.top,
      end - other.end,
      bottom - other.bottom,
    );
  }

  EdgeInsetsDirectional operator +(EdgeInsetsDirectional other) {
    return EdgeInsetsDirectional.fromSTEB(
      start + other.start,
      top + other.top,
      end + other.end,
      bottom + other.bottom,
    );
  }

  @override
  EdgeInsetsDirectional operator -() {
    return EdgeInsetsDirectional.fromSTEB(
      -start,
      -top,
      -end,
      -bottom,
    );
  }

  @override
  EdgeInsetsDirectional operator *(double other) {
    return EdgeInsetsDirectional.fromSTEB(
      start * other,
      top * other,
      end * other,
      bottom * other,
    );
  }

  @override
  EdgeInsetsDirectional operator /(double other) {
    return EdgeInsetsDirectional.fromSTEB(
      start / other,
      top / other,
      end / other,
      bottom / other,
    );
  }

  @override
  EdgeInsetsDirectional operator ~/(double other) {
    return EdgeInsetsDirectional.fromSTEB(
      (start ~/ other).toDouble(),
      (top ~/ other).toDouble(),
      (end ~/ other).toDouble(),
      (bottom ~/ other).toDouble(),
    );
  }

  @override
  EdgeInsetsDirectional operator %(double other) {
    return EdgeInsetsDirectional.fromSTEB(
      start % other,
      top % other,
      end % other,
      bottom % other,
    );
  }

  static EdgeInsetsDirectional? lerp(EdgeInsetsDirectional? a, EdgeInsetsDirectional? b, double t) {
    if (identical(a, b)) {
      return a;
    }
    if (a == null) {
      return b! * t;
    }
    if (b == null) {
      return a * (1.0 - t);
    }
    return EdgeInsetsDirectional.fromSTEB(
      ui.lerpDouble(a.start, b.start, t)!,
      ui.lerpDouble(a.top, b.top, t)!,
      ui.lerpDouble(a.end, b.end, t)!,
      ui.lerpDouble(a.bottom, b.bottom, t)!,
    );
  }

  @override
  EdgeInsets resolve(TextDirection? direction) {
    assert(direction != null);
    switch (direction!) {
      case TextDirection.rtl:
        return EdgeInsets.fromLTRB(end, top, start, bottom);
      case TextDirection.ltr:
        return EdgeInsets.fromLTRB(start, top, end, bottom);
    }
  }
}

class _MixedEdgeInsets extends EdgeInsetsGeometry {
  const _MixedEdgeInsets.fromLRSETB(this._left, this._right, this._start, this._end, this._top, this._bottom);

  @override
  final double _left;

  @override
  final double _right;

  @override
  final double _start;

  @override
  final double _end;

  @override
  final double _top;

  @override
  final double _bottom;

  @override
  bool get isNonNegative {
    return _left >= 0.0
        && _right >= 0.0
        && _start >= 0.0
        && _end >= 0.0
        && _top >= 0.0
        && _bottom >= 0.0;
  }

  @override
  _MixedEdgeInsets operator -() {
    return _MixedEdgeInsets.fromLRSETB(
      -_left,
      -_right,
      -_start,
      -_end,
      -_top,
      -_bottom,
    );
  }

  @override
  _MixedEdgeInsets operator *(double other) {
    return _MixedEdgeInsets.fromLRSETB(
      _left * other,
      _right * other,
      _start * other,
      _end * other,
      _top * other,
      _bottom * other,
    );
  }

  @override
  _MixedEdgeInsets operator /(double other) {
    return _MixedEdgeInsets.fromLRSETB(
      _left / other,
      _right / other,
      _start / other,
      _end / other,
      _top / other,
      _bottom / other,
    );
  }

  @override
  _MixedEdgeInsets operator ~/(double other) {
    return _MixedEdgeInsets.fromLRSETB(
      (_left ~/ other).toDouble(),
      (_right ~/ other).toDouble(),
      (_start ~/ other).toDouble(),
      (_end ~/ other).toDouble(),
      (_top ~/ other).toDouble(),
      (_bottom ~/ other).toDouble(),
    );
  }

  @override
  _MixedEdgeInsets operator %(double other) {
    return _MixedEdgeInsets.fromLRSETB(
      _left % other,
      _right % other,
      _start % other,
      _end % other,
      _top % other,
      _bottom % other,
    );
  }

  @override
  EdgeInsets resolve(TextDirection? direction) {
    assert(direction != null);
    switch (direction!) {
      case TextDirection.rtl:
        return EdgeInsets.fromLTRB(_end + _left, _top, _start + _right, _bottom);
      case TextDirection.ltr:
        return EdgeInsets.fromLTRB(_start + _left, _top, _end + _right, _bottom);
    }
  }
}