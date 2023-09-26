import 'dart:ui' show Color, Rect, Size;

import 'package:flutter/foundation.dart';

import 'animations.dart';

export 'dart:ui' show Color, Rect, Size;

export 'animation.dart' show Animation;
export 'curves.dart' show Curve;

// Examples can assume:
// late Animation<Offset> _animation;
// late AnimationController _controller;

typedef AnimatableCallback<T> = T Function(double);

abstract class Animatable<T> {
  const Animatable();

  const factory Animatable.fromCallback(AnimatableCallback<T> callback) =
      _CallbackAnimatable<T>;

  T transform(double t);

  T evaluate(Animation<double> animation) => transform(animation.value);

  Animation<T> animate(Animation<double> parent) {
    return _AnimatedEvaluation<T>(parent, this);
  }

  Animatable<T> chain(Animatable<double> parent) {
    return _ChainedEvaluation<T>(parent, this);
  }
}

// A concrete subclass of `Animatable` used by `Animatable.fromCallback`.
class _CallbackAnimatable<T> extends Animatable<T> {
  const _CallbackAnimatable(this._callback);

  final AnimatableCallback<T> _callback;

  @override
  T transform(double t) {
    return _callback(t);
  }
}

class _AnimatedEvaluation<T> extends Animation<T>
    with AnimationWithParentMixin<double> {
  _AnimatedEvaluation(this.parent, this._evaluatable);

  @override
  final Animation<double> parent;

  final Animatable<T> _evaluatable;

  @override
  T get value => _evaluatable.evaluate(parent);

  @override
  String toString() {
    return '$parent\u27A9$_evaluatable\u27A9$value';
  }

  @override
  String toStringDetails() {
    return '${super.toStringDetails()} $_evaluatable';
  }
}

class _ChainedEvaluation<T> extends Animatable<T> {
  _ChainedEvaluation(this._parent, this._evaluatable);

  final Animatable<double> _parent;
  final Animatable<T> _evaluatable;

  @override
  T transform(double t) {
    return _evaluatable.transform(_parent.transform(t));
  }

  @override
  String toString() {
    return '$_parent\u27A9$_evaluatable';
  }
}

class Tween<T extends Object?> extends Animatable<T> {
  Tween({
    this.begin,
    this.end,
  });

  T? begin;

  T? end;

  @protected
  T lerp(double t) {
    assert(begin != null);
    assert(end != null);
    assert(() {
      // Assertions that attempt to catch common cases of tweening types
      // that do not conform to the Tween requirements.
      dynamic result;
      try {
        // ignore: avoid_dynamic_calls
        result =
            (begin as dynamic) + ((end as dynamic) - (begin as dynamic)) * t;
        result as T;
        return true;
      } on NoSuchMethodError {
        throw FlutterError.fromParts(<DiagnosticsNode>[
          ErrorSummary('Cannot lerp between "$begin" and "$end".'),
          ErrorDescription(
            'The type ${begin.runtimeType} might not fully implement `+`, `-`, and/or `*`. '
            'See "Types with special considerations" at https://api.flutter.dev/flutter/animation/Tween-class.html '
            'for more information.',
          ),
          if (begin is Color || end is Color)
            ErrorHint('To lerp colors, consider ColorTween instead.')
          else if (begin is Rect || end is Rect)
            ErrorHint('To lerp rects, consider RectTween instead.')
          else
            ErrorHint(
              'There may be a dedicated "${begin.runtimeType}Tween" for this type, '
              'or you may need to create one.',
            ),
        ]);
      } on TypeError {
        throw FlutterError.fromParts(<DiagnosticsNode>[
          ErrorSummary('Cannot lerp between "$begin" and "$end".'),
          ErrorDescription(
            'The type ${begin.runtimeType} returned a ${result.runtimeType} after '
            'multiplication with a double value. '
            'See "Types with special considerations" at https://api.flutter.dev/flutter/animation/Tween-class.html '
            'for more information.',
          ),
          if (begin is int || end is int)
            ErrorHint(
                'To lerp int values, consider IntTween or StepTween instead.')
          else
            ErrorHint(
              'There may be a dedicated "${begin.runtimeType}Tween" for this type, '
              'or you may need to create one.',
            ),
        ]);
      }
    }());
    // ignore: avoid_dynamic_calls
    return (begin as dynamic) + ((end as dynamic) - (begin as dynamic)) * t
        as T;
  }

  @override
  T transform(double t) {
    if (t == 0.0) {
      return begin as T;
    }
    if (t == 1.0) {
      return end as T;
    }
    return lerp(t);
  }

  @override
  String toString() =>
      '${objectRuntimeType(this, 'Animatable')}($begin \u2192 $end)';
}

class ReverseTween<T extends Object?> extends Tween<T> {
  ReverseTween(this.parent) : super(begin: parent.end, end: parent.begin);

  final Tween<T> parent;

  @override
  T lerp(double t) => parent.lerp(1.0 - t);
}

class ColorTween extends Tween<Color?> {
  ColorTween({super.begin, super.end});

  @override
  Color? lerp(double t) => Color.lerp(begin, end, t);
}

class SizeTween extends Tween<Size?> {
  SizeTween({super.begin, super.end});

  @override
  Size? lerp(double t) => Size.lerp(begin, end, t);
}

class RectTween extends Tween<Rect?> {
  RectTween({super.begin, super.end});

  @override
  Rect? lerp(double t) => Rect.lerp(begin, end, t);
}

class IntTween extends Tween<int> {
  IntTween({super.begin, super.end});

  // The inherited lerp() function doesn't work with ints because it multiplies
  // the begin and end types by a double, and int * double returns a double.
  @override
  int lerp(double t) => (begin! + (end! - begin!) * t).round();
}

class StepTween extends Tween<int> {
  StepTween({super.begin, super.end});

  // The inherited lerp() function doesn't work with ints because it multiplies
  // the begin and end types by a double, and int * double returns a double.
  @override
  int lerp(double t) => (begin! + (end! - begin!) * t).floor();
}

class ConstantTween<T> extends Tween<T> {
  ConstantTween(T value) : super(begin: value, end: value);

  @override
  T lerp(double t) => begin as T;

  @override
  String toString() =>
      '${objectRuntimeType(this, 'ConstantTween')}(value: $begin)';
}

class CurveTween extends Animatable<double> {
  CurveTween({required this.curve});

  Curve curve;

  @override
  double transform(double t) {
    if (t == 0.0 || t == 1.0) {
      assert(curve.transform(t).round() == t);
      return t;
    }
    return curve.transform(t);
  }

  @override
  String toString() =>
      '${objectRuntimeType(this, 'CurveTween')}(curve: $curve)';
}
