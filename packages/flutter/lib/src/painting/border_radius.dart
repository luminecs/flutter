import 'package:flutter/foundation.dart';

import 'basic_types.dart';

@immutable
abstract class BorderRadiusGeometry {
  const BorderRadiusGeometry();

  Radius get _topLeft;
  Radius get _topRight;
  Radius get _bottomLeft;
  Radius get _bottomRight;
  Radius get _topStart;
  Radius get _topEnd;
  Radius get _bottomStart;
  Radius get _bottomEnd;

  BorderRadiusGeometry subtract(BorderRadiusGeometry other) {
    return _MixedBorderRadius(
      _topLeft - other._topLeft,
      _topRight - other._topRight,
      _bottomLeft - other._bottomLeft,
      _bottomRight - other._bottomRight,
      _topStart - other._topStart,
      _topEnd - other._topEnd,
      _bottomStart - other._bottomStart,
      _bottomEnd - other._bottomEnd,
    );
  }

  BorderRadiusGeometry add(BorderRadiusGeometry other) {
    return _MixedBorderRadius(
      _topLeft + other._topLeft,
      _topRight + other._topRight,
      _bottomLeft + other._bottomLeft,
      _bottomRight + other._bottomRight,
      _topStart + other._topStart,
      _topEnd + other._topEnd,
      _bottomStart + other._bottomStart,
      _bottomEnd + other._bottomEnd,
    );
  }

  BorderRadiusGeometry operator -();

  BorderRadiusGeometry operator *(double other);

  BorderRadiusGeometry operator /(double other);

  BorderRadiusGeometry operator ~/(double other);

  BorderRadiusGeometry operator %(double other);

  static BorderRadiusGeometry? lerp(
      BorderRadiusGeometry? a, BorderRadiusGeometry? b, double t) {
    if (identical(a, b)) {
      return a;
    }
    a ??= BorderRadius.zero;
    b ??= BorderRadius.zero;
    return a.add((b.subtract(a)) * t);
  }

  BorderRadius resolve(TextDirection? direction);

  @override
  String toString() {
    String? visual, logical;
    if (_topLeft == _topRight &&
        _topRight == _bottomLeft &&
        _bottomLeft == _bottomRight) {
      if (_topLeft != Radius.zero) {
        if (_topLeft.x == _topLeft.y) {
          visual = 'BorderRadius.circular(${_topLeft.x.toStringAsFixed(1)})';
        } else {
          visual = 'BorderRadius.all($_topLeft)';
        }
      }
    } else {
      // visuals aren't the same and at least one isn't zero
      final StringBuffer result = StringBuffer();
      result.write('BorderRadius.only(');
      bool comma = false;
      if (_topLeft != Radius.zero) {
        result.write('topLeft: $_topLeft');
        comma = true;
      }
      if (_topRight != Radius.zero) {
        if (comma) {
          result.write(', ');
        }
        result.write('topRight: $_topRight');
        comma = true;
      }
      if (_bottomLeft != Radius.zero) {
        if (comma) {
          result.write(', ');
        }
        result.write('bottomLeft: $_bottomLeft');
        comma = true;
      }
      if (_bottomRight != Radius.zero) {
        if (comma) {
          result.write(', ');
        }
        result.write('bottomRight: $_bottomRight');
      }
      result.write(')');
      visual = result.toString();
    }
    if (_topStart == _topEnd &&
        _topEnd == _bottomEnd &&
        _bottomEnd == _bottomStart) {
      if (_topStart != Radius.zero) {
        if (_topStart.x == _topStart.y) {
          logical =
              'BorderRadiusDirectional.circular(${_topStart.x.toStringAsFixed(1)})';
        } else {
          logical = 'BorderRadiusDirectional.all($_topStart)';
        }
      }
    } else {
      // logicals aren't the same and at least one isn't zero
      final StringBuffer result = StringBuffer();
      result.write('BorderRadiusDirectional.only(');
      bool comma = false;
      if (_topStart != Radius.zero) {
        result.write('topStart: $_topStart');
        comma = true;
      }
      if (_topEnd != Radius.zero) {
        if (comma) {
          result.write(', ');
        }
        result.write('topEnd: $_topEnd');
        comma = true;
      }
      if (_bottomStart != Radius.zero) {
        if (comma) {
          result.write(', ');
        }
        result.write('bottomStart: $_bottomStart');
        comma = true;
      }
      if (_bottomEnd != Radius.zero) {
        if (comma) {
          result.write(', ');
        }
        result.write('bottomEnd: $_bottomEnd');
      }
      result.write(')');
      logical = result.toString();
    }
    if (visual != null && logical != null) {
      return '$visual + $logical';
    }
    if (visual != null) {
      return visual;
    }
    if (logical != null) {
      return logical;
    }
    return 'BorderRadius.zero';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is BorderRadiusGeometry &&
        other._topLeft == _topLeft &&
        other._topRight == _topRight &&
        other._bottomLeft == _bottomLeft &&
        other._bottomRight == _bottomRight &&
        other._topStart == _topStart &&
        other._topEnd == _topEnd &&
        other._bottomStart == _bottomStart &&
        other._bottomEnd == _bottomEnd;
  }

  @override
  int get hashCode => Object.hash(
        _topLeft,
        _topRight,
        _bottomLeft,
        _bottomRight,
        _topStart,
        _topEnd,
        _bottomStart,
        _bottomEnd,
      );
}

class BorderRadius extends BorderRadiusGeometry {
  const BorderRadius.all(Radius radius)
      : this.only(
          topLeft: radius,
          topRight: radius,
          bottomLeft: radius,
          bottomRight: radius,
        );

  BorderRadius.circular(double radius)
      : this.all(
          Radius.circular(radius),
        );

  const BorderRadius.vertical({
    Radius top = Radius.zero,
    Radius bottom = Radius.zero,
  }) : this.only(
          topLeft: top,
          topRight: top,
          bottomLeft: bottom,
          bottomRight: bottom,
        );

  const BorderRadius.horizontal({
    Radius left = Radius.zero,
    Radius right = Radius.zero,
  }) : this.only(
          topLeft: left,
          topRight: right,
          bottomLeft: left,
          bottomRight: right,
        );

  const BorderRadius.only({
    this.topLeft = Radius.zero,
    this.topRight = Radius.zero,
    this.bottomLeft = Radius.zero,
    this.bottomRight = Radius.zero,
  });

  BorderRadius copyWith({
    Radius? topLeft,
    Radius? topRight,
    Radius? bottomLeft,
    Radius? bottomRight,
  }) {
    return BorderRadius.only(
      topLeft: topLeft ?? this.topLeft,
      topRight: topRight ?? this.topRight,
      bottomLeft: bottomLeft ?? this.bottomLeft,
      bottomRight: bottomRight ?? this.bottomRight,
    );
  }

  static const BorderRadius zero = BorderRadius.all(Radius.zero);

  final Radius topLeft;

  @override
  Radius get _topLeft => topLeft;

  final Radius topRight;

  @override
  Radius get _topRight => topRight;

  final Radius bottomLeft;

  @override
  Radius get _bottomLeft => bottomLeft;

  final Radius bottomRight;

  @override
  Radius get _bottomRight => bottomRight;

  @override
  Radius get _topStart => Radius.zero;

  @override
  Radius get _topEnd => Radius.zero;

  @override
  Radius get _bottomStart => Radius.zero;

  @override
  Radius get _bottomEnd => Radius.zero;

  RRect toRRect(Rect rect) {
    // Because the current radii could be negative, we must clamp them before
    // converting them to an RRect to be rendered, since negative radii on
    // RRects don't make sense.
    return RRect.fromRectAndCorners(
      rect,
      topLeft: topLeft.clamp(minimum: Radius.zero), // ignore_clamp_double_lint
      topRight:
          topRight.clamp(minimum: Radius.zero), // ignore_clamp_double_lint
      bottomLeft:
          bottomLeft.clamp(minimum: Radius.zero), // ignore_clamp_double_lint
      bottomRight:
          bottomRight.clamp(minimum: Radius.zero), // ignore_clamp_double_lint
    );
  }

  @override
  BorderRadiusGeometry subtract(BorderRadiusGeometry other) {
    if (other is BorderRadius) {
      return this - other;
    }
    return super.subtract(other);
  }

  @override
  BorderRadiusGeometry add(BorderRadiusGeometry other) {
    if (other is BorderRadius) {
      return this + other;
    }
    return super.add(other);
  }

  BorderRadius operator -(BorderRadius other) {
    return BorderRadius.only(
      topLeft: topLeft - other.topLeft,
      topRight: topRight - other.topRight,
      bottomLeft: bottomLeft - other.bottomLeft,
      bottomRight: bottomRight - other.bottomRight,
    );
  }

  BorderRadius operator +(BorderRadius other) {
    return BorderRadius.only(
      topLeft: topLeft + other.topLeft,
      topRight: topRight + other.topRight,
      bottomLeft: bottomLeft + other.bottomLeft,
      bottomRight: bottomRight + other.bottomRight,
    );
  }

  @override
  BorderRadius operator -() {
    return BorderRadius.only(
      topLeft: -topLeft,
      topRight: -topRight,
      bottomLeft: -bottomLeft,
      bottomRight: -bottomRight,
    );
  }

  @override
  BorderRadius operator *(double other) {
    return BorderRadius.only(
      topLeft: topLeft * other,
      topRight: topRight * other,
      bottomLeft: bottomLeft * other,
      bottomRight: bottomRight * other,
    );
  }

  @override
  BorderRadius operator /(double other) {
    return BorderRadius.only(
      topLeft: topLeft / other,
      topRight: topRight / other,
      bottomLeft: bottomLeft / other,
      bottomRight: bottomRight / other,
    );
  }

  @override
  BorderRadius operator ~/(double other) {
    return BorderRadius.only(
      topLeft: topLeft ~/ other,
      topRight: topRight ~/ other,
      bottomLeft: bottomLeft ~/ other,
      bottomRight: bottomRight ~/ other,
    );
  }

  @override
  BorderRadius operator %(double other) {
    return BorderRadius.only(
      topLeft: topLeft % other,
      topRight: topRight % other,
      bottomLeft: bottomLeft % other,
      bottomRight: bottomRight % other,
    );
  }

  static BorderRadius? lerp(BorderRadius? a, BorderRadius? b, double t) {
    if (identical(a, b)) {
      return a;
    }
    if (a == null) {
      return b! * t;
    }
    if (b == null) {
      return a * (1.0 - t);
    }
    return BorderRadius.only(
      topLeft: Radius.lerp(a.topLeft, b.topLeft, t)!,
      topRight: Radius.lerp(a.topRight, b.topRight, t)!,
      bottomLeft: Radius.lerp(a.bottomLeft, b.bottomLeft, t)!,
      bottomRight: Radius.lerp(a.bottomRight, b.bottomRight, t)!,
    );
  }

  @override
  BorderRadius resolve(TextDirection? direction) => this;
}

class BorderRadiusDirectional extends BorderRadiusGeometry {
  const BorderRadiusDirectional.all(Radius radius)
      : this.only(
          topStart: radius,
          topEnd: radius,
          bottomStart: radius,
          bottomEnd: radius,
        );

  BorderRadiusDirectional.circular(double radius)
      : this.all(
          Radius.circular(radius),
        );

  const BorderRadiusDirectional.vertical({
    Radius top = Radius.zero,
    Radius bottom = Radius.zero,
  }) : this.only(
          topStart: top,
          topEnd: top,
          bottomStart: bottom,
          bottomEnd: bottom,
        );

  const BorderRadiusDirectional.horizontal({
    Radius start = Radius.zero,
    Radius end = Radius.zero,
  }) : this.only(
          topStart: start,
          topEnd: end,
          bottomStart: start,
          bottomEnd: end,
        );

  const BorderRadiusDirectional.only({
    this.topStart = Radius.zero,
    this.topEnd = Radius.zero,
    this.bottomStart = Radius.zero,
    this.bottomEnd = Radius.zero,
  });

  static const BorderRadiusDirectional zero =
      BorderRadiusDirectional.all(Radius.zero);

  final Radius topStart;

  @override
  Radius get _topStart => topStart;

  final Radius topEnd;

  @override
  Radius get _topEnd => topEnd;

  final Radius bottomStart;

  @override
  Radius get _bottomStart => bottomStart;

  final Radius bottomEnd;

  @override
  Radius get _bottomEnd => bottomEnd;

  @override
  Radius get _topLeft => Radius.zero;

  @override
  Radius get _topRight => Radius.zero;

  @override
  Radius get _bottomLeft => Radius.zero;

  @override
  Radius get _bottomRight => Radius.zero;

  @override
  BorderRadiusGeometry subtract(BorderRadiusGeometry other) {
    if (other is BorderRadiusDirectional) {
      return this - other;
    }
    return super.subtract(other);
  }

  @override
  BorderRadiusGeometry add(BorderRadiusGeometry other) {
    if (other is BorderRadiusDirectional) {
      return this + other;
    }
    return super.add(other);
  }

  BorderRadiusDirectional operator -(BorderRadiusDirectional other) {
    return BorderRadiusDirectional.only(
      topStart: topStart - other.topStart,
      topEnd: topEnd - other.topEnd,
      bottomStart: bottomStart - other.bottomStart,
      bottomEnd: bottomEnd - other.bottomEnd,
    );
  }

  BorderRadiusDirectional operator +(BorderRadiusDirectional other) {
    return BorderRadiusDirectional.only(
      topStart: topStart + other.topStart,
      topEnd: topEnd + other.topEnd,
      bottomStart: bottomStart + other.bottomStart,
      bottomEnd: bottomEnd + other.bottomEnd,
    );
  }

  @override
  BorderRadiusDirectional operator -() {
    return BorderRadiusDirectional.only(
      topStart: -topStart,
      topEnd: -topEnd,
      bottomStart: -bottomStart,
      bottomEnd: -bottomEnd,
    );
  }

  @override
  BorderRadiusDirectional operator *(double other) {
    return BorderRadiusDirectional.only(
      topStart: topStart * other,
      topEnd: topEnd * other,
      bottomStart: bottomStart * other,
      bottomEnd: bottomEnd * other,
    );
  }

  @override
  BorderRadiusDirectional operator /(double other) {
    return BorderRadiusDirectional.only(
      topStart: topStart / other,
      topEnd: topEnd / other,
      bottomStart: bottomStart / other,
      bottomEnd: bottomEnd / other,
    );
  }

  @override
  BorderRadiusDirectional operator ~/(double other) {
    return BorderRadiusDirectional.only(
      topStart: topStart ~/ other,
      topEnd: topEnd ~/ other,
      bottomStart: bottomStart ~/ other,
      bottomEnd: bottomEnd ~/ other,
    );
  }

  @override
  BorderRadiusDirectional operator %(double other) {
    return BorderRadiusDirectional.only(
      topStart: topStart % other,
      topEnd: topEnd % other,
      bottomStart: bottomStart % other,
      bottomEnd: bottomEnd % other,
    );
  }

  static BorderRadiusDirectional? lerp(
      BorderRadiusDirectional? a, BorderRadiusDirectional? b, double t) {
    if (identical(a, b)) {
      return a;
    }
    if (a == null) {
      return b! * t;
    }
    if (b == null) {
      return a * (1.0 - t);
    }
    return BorderRadiusDirectional.only(
      topStart: Radius.lerp(a.topStart, b.topStart, t)!,
      topEnd: Radius.lerp(a.topEnd, b.topEnd, t)!,
      bottomStart: Radius.lerp(a.bottomStart, b.bottomStart, t)!,
      bottomEnd: Radius.lerp(a.bottomEnd, b.bottomEnd, t)!,
    );
  }

  @override
  BorderRadius resolve(TextDirection? direction) {
    assert(direction != null);
    switch (direction!) {
      case TextDirection.rtl:
        return BorderRadius.only(
          topLeft: topEnd,
          topRight: topStart,
          bottomLeft: bottomEnd,
          bottomRight: bottomStart,
        );
      case TextDirection.ltr:
        return BorderRadius.only(
          topLeft: topStart,
          topRight: topEnd,
          bottomLeft: bottomStart,
          bottomRight: bottomEnd,
        );
    }
  }
}

class _MixedBorderRadius extends BorderRadiusGeometry {
  const _MixedBorderRadius(
    this._topLeft,
    this._topRight,
    this._bottomLeft,
    this._bottomRight,
    this._topStart,
    this._topEnd,
    this._bottomStart,
    this._bottomEnd,
  );

  @override
  final Radius _topLeft;

  @override
  final Radius _topRight;

  @override
  final Radius _bottomLeft;

  @override
  final Radius _bottomRight;

  @override
  final Radius _topStart;

  @override
  final Radius _topEnd;

  @override
  final Radius _bottomStart;

  @override
  final Radius _bottomEnd;

  @override
  _MixedBorderRadius operator -() {
    return _MixedBorderRadius(
      -_topLeft,
      -_topRight,
      -_bottomLeft,
      -_bottomRight,
      -_topStart,
      -_topEnd,
      -_bottomStart,
      -_bottomEnd,
    );
  }

  @override
  _MixedBorderRadius operator *(double other) {
    return _MixedBorderRadius(
      _topLeft * other,
      _topRight * other,
      _bottomLeft * other,
      _bottomRight * other,
      _topStart * other,
      _topEnd * other,
      _bottomStart * other,
      _bottomEnd * other,
    );
  }

  @override
  _MixedBorderRadius operator /(double other) {
    return _MixedBorderRadius(
      _topLeft / other,
      _topRight / other,
      _bottomLeft / other,
      _bottomRight / other,
      _topStart / other,
      _topEnd / other,
      _bottomStart / other,
      _bottomEnd / other,
    );
  }

  @override
  _MixedBorderRadius operator ~/(double other) {
    return _MixedBorderRadius(
      _topLeft ~/ other,
      _topRight ~/ other,
      _bottomLeft ~/ other,
      _bottomRight ~/ other,
      _topStart ~/ other,
      _topEnd ~/ other,
      _bottomStart ~/ other,
      _bottomEnd ~/ other,
    );
  }

  @override
  _MixedBorderRadius operator %(double other) {
    return _MixedBorderRadius(
      _topLeft % other,
      _topRight % other,
      _bottomLeft % other,
      _bottomRight % other,
      _topStart % other,
      _topEnd % other,
      _bottomStart % other,
      _bottomEnd % other,
    );
  }

  @override
  BorderRadius resolve(TextDirection? direction) {
    assert(direction != null);
    switch (direction!) {
      case TextDirection.rtl:
        return BorderRadius.only(
          topLeft: _topLeft + _topEnd,
          topRight: _topRight + _topStart,
          bottomLeft: _bottomLeft + _bottomEnd,
          bottomRight: _bottomRight + _bottomStart,
        );
      case TextDirection.ltr:
        return BorderRadius.only(
          topLeft: _topLeft + _topStart,
          topRight: _topRight + _topEnd,
          bottomLeft: _bottomLeft + _bottomStart,
          bottomRight: _bottomRight + _bottomEnd,
        );
    }
  }
}
