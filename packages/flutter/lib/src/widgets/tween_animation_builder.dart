
import 'package:flutter/animation.dart';

import 'framework.dart';
import 'implicit_animations.dart';
import 'value_listenable_builder.dart';

class TweenAnimationBuilder<T extends Object?> extends ImplicitlyAnimatedWidget {
  const TweenAnimationBuilder({
    super.key,
    required this.tween,
    required super.duration,
    super.curve,
    required this.builder,
    super.onEnd,
    this.child,
  });

  final Tween<T> tween;

  final ValueWidgetBuilder<T> builder;

  final Widget? child;

  @override
  ImplicitlyAnimatedWidgetState<ImplicitlyAnimatedWidget> createState() {
    return _TweenAnimationBuilderState<T>();
  }
}

class _TweenAnimationBuilderState<T extends Object?> extends AnimatedWidgetBaseState<TweenAnimationBuilder<T>> {
  Tween<T>? _currentTween;

  @override
  void initState() {
    _currentTween = widget.tween;
    _currentTween!.begin ??= _currentTween!.end;
    super.initState();
    if (_currentTween!.begin != _currentTween!.end) {
      controller.forward();
    }
  }

  @override
  void forEachTween(TweenVisitor<dynamic> visitor) {
    assert(
      widget.tween.end != null,
      'Tween provided to TweenAnimationBuilder must have non-null Tween.end value.',
    );
    _currentTween = visitor(_currentTween, widget.tween.end, (dynamic value) {
      assert(false);
      throw StateError('Constructor will never be called because null is never provided as current tween.');
    }) as Tween<T>?;
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, _currentTween!.evaluate(animation), widget.child);
  }
}