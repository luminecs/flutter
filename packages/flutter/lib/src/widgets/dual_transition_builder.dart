import 'basic.dart';
import 'framework.dart';

typedef AnimatedTransitionBuilder = Widget Function(
  BuildContext context,
  Animation<double> animation,
  Widget? child,
);

class DualTransitionBuilder extends StatefulWidget {
  const DualTransitionBuilder({
    super.key,
    required this.animation,
    required this.forwardBuilder,
    required this.reverseBuilder,
    this.child,
  });

  final Animation<double> animation;

  final AnimatedTransitionBuilder forwardBuilder;

  final AnimatedTransitionBuilder reverseBuilder;

  final Widget? child;

  @override
  State<DualTransitionBuilder> createState() => _DualTransitionBuilderState();
}

class _DualTransitionBuilderState extends State<DualTransitionBuilder> {
  late AnimationStatus _effectiveAnimationStatus;
  final ProxyAnimation _forwardAnimation = ProxyAnimation();
  final ProxyAnimation _reverseAnimation = ProxyAnimation();

  @override
  void initState() {
    super.initState();
    _effectiveAnimationStatus = widget.animation.status;
    widget.animation.addStatusListener(_animationListener);
    _updateAnimations();
  }

  void _animationListener(AnimationStatus animationStatus) {
    final AnimationStatus oldEffective = _effectiveAnimationStatus;
    _effectiveAnimationStatus = _calculateEffectiveAnimationStatus(
      lastEffective: _effectiveAnimationStatus,
      current: animationStatus,
    );
    if (oldEffective != _effectiveAnimationStatus) {
      _updateAnimations();
    }
  }

  @override
  void didUpdateWidget(DualTransitionBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animation != widget.animation) {
      oldWidget.animation.removeStatusListener(_animationListener);
      widget.animation.addStatusListener(_animationListener);
      _animationListener(widget.animation.status);
    }
  }

  // When a transition is interrupted midway we just want to play the ongoing
  // animation in reverse. Switching to the actual reverse transition would
  // yield a disjoint experience since the forward and reverse transitions are
  // very different.
  AnimationStatus _calculateEffectiveAnimationStatus({
    required AnimationStatus lastEffective,
    required AnimationStatus current,
  }) {
    switch (current) {
      case AnimationStatus.dismissed:
      case AnimationStatus.completed:
        return current;
      case AnimationStatus.forward:
        switch (lastEffective) {
          case AnimationStatus.dismissed:
          case AnimationStatus.completed:
          case AnimationStatus.forward:
            return current;
          case AnimationStatus.reverse:
            return lastEffective;
        }
      case AnimationStatus.reverse:
        switch (lastEffective) {
          case AnimationStatus.dismissed:
          case AnimationStatus.completed:
          case AnimationStatus.reverse:
            return current;
          case AnimationStatus.forward:
            return lastEffective;
        }
    }
  }

  void _updateAnimations() {
    switch (_effectiveAnimationStatus) {
      case AnimationStatus.dismissed:
      case AnimationStatus.forward:
        _forwardAnimation.parent = widget.animation;
        _reverseAnimation.parent = kAlwaysDismissedAnimation;
      case AnimationStatus.reverse:
      case AnimationStatus.completed:
        _forwardAnimation.parent = kAlwaysCompleteAnimation;
        _reverseAnimation.parent = ReverseAnimation(widget.animation);
    }
  }

  @override
  void dispose() {
    widget.animation.removeStatusListener(_animationListener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.forwardBuilder(
      context,
      _forwardAnimation,
      widget.reverseBuilder(
        context,
        _reverseAnimation,
        widget.child,
      ),
    );
  }
}
