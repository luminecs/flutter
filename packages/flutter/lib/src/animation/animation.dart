
import 'package:flutter/foundation.dart';

import 'tween.dart';

export 'dart:ui' show VoidCallback;

export 'tween.dart' show Animatable;

// Examples can assume:
// late AnimationController _controller;
// late ValueNotifier<double> _scrollPosition;

enum AnimationStatus {
  dismissed,

  forward,

  reverse,

  completed,
}

typedef AnimationStatusListener = void Function(AnimationStatus status);

typedef ValueListenableTransformer<T> = T Function(T);

abstract class Animation<T> extends Listenable implements ValueListenable<T> {
  const Animation();

  factory Animation.fromValueListenable(ValueListenable<T> listenable, {
    ValueListenableTransformer<T>? transformer,
  }) = _ValueListenableDelegateAnimation<T>;

  // keep these next five dartdocs in sync with the dartdocs in AnimationWithParentMixin<T>

  @override
  void addListener(VoidCallback listener);

  @override
  void removeListener(VoidCallback listener);

  void addStatusListener(AnimationStatusListener listener);

  void removeStatusListener(AnimationStatusListener listener);

  AnimationStatus get status;

  @override
  T get value;

  bool get isDismissed => status == AnimationStatus.dismissed;

  bool get isCompleted => status == AnimationStatus.completed;

  @optionalTypeArgs
  Animation<U> drive<U>(Animatable<U> child) {
    assert(this is Animation<double>);
    return child.animate(this as Animation<double>);
  }

  @override
  String toString() {
    return '${describeIdentity(this)}(${toStringDetails()})';
  }

  String toStringDetails() {
    switch (status) {
      case AnimationStatus.forward:
        return '\u25B6'; // >
      case AnimationStatus.reverse:
        return '\u25C0'; // <
      case AnimationStatus.completed:
        return '\u23ED'; // >>|
      case AnimationStatus.dismissed:
        return '\u23EE'; // |<<
    }
  }
}

// An implementation of an animation that delegates to a value listenable with a fixed direction.
class _ValueListenableDelegateAnimation<T> extends Animation<T> {
  _ValueListenableDelegateAnimation(this._listenable, {
    ValueListenableTransformer<T>? transformer,
  }) : _transformer = transformer;

  final ValueListenable<T> _listenable;
  final ValueListenableTransformer<T>? _transformer;

  @override
  void addListener(VoidCallback listener) {
    _listenable.addListener(listener);
  }

  @override
  void addStatusListener(AnimationStatusListener listener) {
    // status will never change.
  }

  @override
  void removeListener(VoidCallback listener) {
    _listenable.removeListener(listener);
  }

  @override
  void removeStatusListener(AnimationStatusListener listener) {
    // status will never change.
  }

  @override
  AnimationStatus get status => AnimationStatus.forward;

  @override
  T get value => _transformer?.call(_listenable.value) ?? _listenable.value;
}