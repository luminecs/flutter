import 'dart:ui' as ui show lerpDouble;

import 'package:flutter/foundation.dart';

import 'basic_types.dart';

@immutable
abstract class AlignmentGeometry {
  const AlignmentGeometry();

  double get _x;

  double get _start;

  double get _y;

  AlignmentGeometry add(AlignmentGeometry other) {
    return _MixedAlignment(
      _x + other._x,
      _start + other._start,
      _y + other._y,
    );
  }

  AlignmentGeometry operator -();

  AlignmentGeometry operator *(double other);

  AlignmentGeometry operator /(double other);

  AlignmentGeometry operator ~/(double other);

  AlignmentGeometry operator %(double other);

  static AlignmentGeometry? lerp(AlignmentGeometry? a, AlignmentGeometry? b, double t) {
    if (identical(a, b)) {
      return a;
    }
    if (a == null) {
      return b! * t;
    }
    if (b == null) {
      return a * (1.0 - t);
    }
    if (a is Alignment && b is Alignment) {
      return Alignment.lerp(a, b, t);
    }
    if (a is AlignmentDirectional && b is AlignmentDirectional) {
      return AlignmentDirectional.lerp(a, b, t);
    }
    return _MixedAlignment(
      ui.lerpDouble(a._x, b._x, t)!,
      ui.lerpDouble(a._start, b._start, t)!,
      ui.lerpDouble(a._y, b._y, t)!,
    );
  }

  Alignment resolve(TextDirection? direction);

  @override
  String toString() {
    if (_start == 0.0) {
      return Alignment._stringify(_x, _y);
    }
    if (_x == 0.0) {
      return AlignmentDirectional._stringify(_start, _y);
    }
    return '${Alignment._stringify(_x, _y)} + ${AlignmentDirectional._stringify(_start, 0.0)}';
  }

  @override
  bool operator ==(Object other) {
    return other is AlignmentGeometry
        && other._x == _x
        && other._start == _start
        && other._y == _y;
  }

  @override
  int get hashCode => Object.hash(_x, _start, _y);
}

class Alignment extends AlignmentGeometry {
  const Alignment(this.x, this.y);

  final double x;

  final double y;

  @override
  double get _x => x;

  @override
  double get _start => 0.0;

  @override
  double get _y => y;

  static const Alignment topLeft = Alignment(-1.0, -1.0);

  static const Alignment topCenter = Alignment(0.0, -1.0);

  static const Alignment topRight = Alignment(1.0, -1.0);

  static const Alignment centerLeft = Alignment(-1.0, 0.0);

  static const Alignment center = Alignment(0.0, 0.0);

  static const Alignment centerRight = Alignment(1.0, 0.0);

  static const Alignment bottomLeft = Alignment(-1.0, 1.0);

  static const Alignment bottomCenter = Alignment(0.0, 1.0);

  static const Alignment bottomRight = Alignment(1.0, 1.0);

  @override
  AlignmentGeometry add(AlignmentGeometry other) {
    if (other is Alignment) {
      return this + other;
    }
    return super.add(other);
  }

  Alignment operator -(Alignment other) {
    return Alignment(x - other.x, y - other.y);
  }

  Alignment operator +(Alignment other) {
    return Alignment(x + other.x, y + other.y);
  }

  @override
  Alignment operator -() {
    return Alignment(-x, -y);
  }

  @override
  Alignment operator *(double other) {
    return Alignment(x * other, y * other);
  }

  @override
  Alignment operator /(double other) {
    return Alignment(x / other, y / other);
  }

  @override
  Alignment operator ~/(double other) {
    return Alignment((x ~/ other).toDouble(), (y ~/ other).toDouble());
  }

  @override
  Alignment operator %(double other) {
    return Alignment(x % other, y % other);
  }

  Offset alongOffset(Offset other) {
    final double centerX = other.dx / 2.0;
    final double centerY = other.dy / 2.0;
    return Offset(centerX + x * centerX, centerY + y * centerY);
  }

  Offset alongSize(Size other) {
    final double centerX = other.width / 2.0;
    final double centerY = other.height / 2.0;
    return Offset(centerX + x * centerX, centerY + y * centerY);
  }

  Offset withinRect(Rect rect) {
    final double halfWidth = rect.width / 2.0;
    final double halfHeight = rect.height / 2.0;
    return Offset(
      rect.left + halfWidth + x * halfWidth,
      rect.top + halfHeight + y * halfHeight,
    );
  }

  Rect inscribe(Size size, Rect rect) {
    final double halfWidthDelta = (rect.width - size.width) / 2.0;
    final double halfHeightDelta = (rect.height - size.height) / 2.0;
    return Rect.fromLTWH(
      rect.left + halfWidthDelta + x * halfWidthDelta,
      rect.top + halfHeightDelta + y * halfHeightDelta,
      size.width,
      size.height,
    );
  }

  static Alignment? lerp(Alignment? a, Alignment? b, double t) {
    if (identical(a, b)) {
      return a;
    }
    if (a == null) {
      return Alignment(ui.lerpDouble(0.0, b!.x, t)!, ui.lerpDouble(0.0, b.y, t)!);
    }
    if (b == null) {
      return Alignment(ui.lerpDouble(a.x, 0.0, t)!, ui.lerpDouble(a.y, 0.0, t)!);
    }
    return Alignment(ui.lerpDouble(a.x, b.x, t)!, ui.lerpDouble(a.y, b.y, t)!);
  }

  @override
  Alignment resolve(TextDirection? direction) => this;

  static String _stringify(double x, double y) {
    if (x == -1.0 && y == -1.0) {
      return 'Alignment.topLeft';
    }
    if (x == 0.0 && y == -1.0) {
      return 'Alignment.topCenter';
    }
    if (x == 1.0 && y == -1.0) {
      return 'Alignment.topRight';
    }
    if (x == -1.0 && y == 0.0) {
      return 'Alignment.centerLeft';
    }
    if (x == 0.0 && y == 0.0) {
      return 'Alignment.center';
    }
    if (x == 1.0 && y == 0.0) {
      return 'Alignment.centerRight';
    }
    if (x == -1.0 && y == 1.0) {
      return 'Alignment.bottomLeft';
    }
    if (x == 0.0 && y == 1.0) {
      return 'Alignment.bottomCenter';
    }
    if (x == 1.0 && y == 1.0) {
      return 'Alignment.bottomRight';
    }
    return 'Alignment(${x.toStringAsFixed(1)}, '
                     '${y.toStringAsFixed(1)})';
  }

  @override
  String toString() => _stringify(x, y);
}

class AlignmentDirectional extends AlignmentGeometry {
  const AlignmentDirectional(this.start, this.y);

  final double start;

  final double y;

  @override
  double get _x => 0.0;

  @override
  double get _start => start;

  @override
  double get _y => y;

  static const AlignmentDirectional topStart = AlignmentDirectional(-1.0, -1.0);

  static const AlignmentDirectional topCenter = AlignmentDirectional(0.0, -1.0);

  static const AlignmentDirectional topEnd = AlignmentDirectional(1.0, -1.0);

  static const AlignmentDirectional centerStart = AlignmentDirectional(-1.0, 0.0);

  static const AlignmentDirectional center = AlignmentDirectional(0.0, 0.0);

  static const AlignmentDirectional centerEnd = AlignmentDirectional(1.0, 0.0);

  static const AlignmentDirectional bottomStart = AlignmentDirectional(-1.0, 1.0);

  static const AlignmentDirectional bottomCenter = AlignmentDirectional(0.0, 1.0);

  static const AlignmentDirectional bottomEnd = AlignmentDirectional(1.0, 1.0);

  @override
  AlignmentGeometry add(AlignmentGeometry other) {
    if (other is AlignmentDirectional) {
      return this + other;
    }
    return super.add(other);
  }

  AlignmentDirectional operator -(AlignmentDirectional other) {
    return AlignmentDirectional(start - other.start, y - other.y);
  }

  AlignmentDirectional operator +(AlignmentDirectional other) {
    return AlignmentDirectional(start + other.start, y + other.y);
  }

  @override
  AlignmentDirectional operator -() {
    return AlignmentDirectional(-start, -y);
  }

  @override
  AlignmentDirectional operator *(double other) {
    return AlignmentDirectional(start * other, y * other);
  }

  @override
  AlignmentDirectional operator /(double other) {
    return AlignmentDirectional(start / other, y / other);
  }

  @override
  AlignmentDirectional operator ~/(double other) {
    return AlignmentDirectional((start ~/ other).toDouble(), (y ~/ other).toDouble());
  }

  @override
  AlignmentDirectional operator %(double other) {
    return AlignmentDirectional(start % other, y % other);
  }

  static AlignmentDirectional? lerp(AlignmentDirectional? a, AlignmentDirectional? b, double t) {
    if (identical(a, b)) {
      return a;
    }
    if (a == null) {
      return AlignmentDirectional(ui.lerpDouble(0.0, b!.start, t)!, ui.lerpDouble(0.0, b.y, t)!);
    }
    if (b == null) {
      return AlignmentDirectional(ui.lerpDouble(a.start, 0.0, t)!, ui.lerpDouble(a.y, 0.0, t)!);
    }
    return AlignmentDirectional(ui.lerpDouble(a.start, b.start, t)!, ui.lerpDouble(a.y, b.y, t)!);
  }

  @override
  Alignment resolve(TextDirection? direction) {
    assert(direction != null, 'Cannot resolve $runtimeType without a TextDirection.');
    switch (direction!) {
      case TextDirection.rtl:
        return Alignment(-start, y);
      case TextDirection.ltr:
        return Alignment(start, y);
    }
  }

  static String _stringify(double start, double y) {
    if (start == -1.0 && y == -1.0) {
      return 'AlignmentDirectional.topStart';
    }
    if (start == 0.0 && y == -1.0) {
      return 'AlignmentDirectional.topCenter';
    }
    if (start == 1.0 && y == -1.0) {
      return 'AlignmentDirectional.topEnd';
    }
    if (start == -1.0 && y == 0.0) {
      return 'AlignmentDirectional.centerStart';
    }
    if (start == 0.0 && y == 0.0) {
      return 'AlignmentDirectional.center';
    }
    if (start == 1.0 && y == 0.0) {
      return 'AlignmentDirectional.centerEnd';
    }
    if (start == -1.0 && y == 1.0) {
      return 'AlignmentDirectional.bottomStart';
    }
    if (start == 0.0 && y == 1.0) {
      return 'AlignmentDirectional.bottomCenter';
    }
    if (start == 1.0 && y == 1.0) {
      return 'AlignmentDirectional.bottomEnd';
    }
    return 'AlignmentDirectional(${start.toStringAsFixed(1)}, '
                                '${y.toStringAsFixed(1)})';
  }

  @override
  String toString() => _stringify(start, y);
}

class _MixedAlignment extends AlignmentGeometry {
  const _MixedAlignment(this._x, this._start, this._y);

  @override
  final double _x;

  @override
  final double _start;

  @override
  final double _y;

  @override
  _MixedAlignment operator -() {
    return _MixedAlignment(
      -_x,
      -_start,
      -_y,
    );
  }

  @override
  _MixedAlignment operator *(double other) {
    return _MixedAlignment(
      _x * other,
      _start * other,
      _y * other,
    );
  }

  @override
  _MixedAlignment operator /(double other) {
    return _MixedAlignment(
      _x / other,
      _start / other,
      _y / other,
    );
  }

  @override
  _MixedAlignment operator ~/(double other) {
    return _MixedAlignment(
      (_x ~/ other).toDouble(),
      (_start ~/ other).toDouble(),
      (_y ~/ other).toDouble(),
    );
  }

  @override
  _MixedAlignment operator %(double other) {
    return _MixedAlignment(
      _x % other,
      _start % other,
      _y % other,
    );
  }

  @override
  Alignment resolve(TextDirection? direction) {
    assert(direction != null, 'Cannot resolve $runtimeType without a TextDirection.');
    switch (direction!) {
      case TextDirection.rtl:
        return Alignment(_x - _start, _y);
      case TextDirection.ltr:
        return Alignment(_x + _start, _y);
    }
  }
}

class TextAlignVertical {
  const TextAlignVertical({
    required this.y,
  }) : assert(y >= -1.0 && y <= 1.0);

  final double y;

  static const TextAlignVertical top = TextAlignVertical(y: -1.0);
  static const TextAlignVertical center = TextAlignVertical(y: 0.0);
  static const TextAlignVertical bottom = TextAlignVertical(y: 1.0);

  @override
  String toString() {
    return '${objectRuntimeType(this, 'TextAlignVertical')}(y: $y)';
  }
}