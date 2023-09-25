import 'package:flutter/widgets.dart';

class _TooltipVisibilityScope extends InheritedWidget {
  const _TooltipVisibilityScope({
    required super.child,
    required this.visible,
  });

  final bool visible;

  @override
  bool updateShouldNotify(_TooltipVisibilityScope old) {
    return old.visible != visible;
  }
}

class TooltipVisibility extends StatelessWidget {
  const TooltipVisibility({
    super.key,
    required this.visible,
    required this.child,
  });

  final Widget child;

  final bool visible;

  static bool of(BuildContext context) {
    final _TooltipVisibilityScope? visibility = context.dependOnInheritedWidgetOfExactType<_TooltipVisibilityScope>();
    return visibility?.visible ?? true;
  }

  @override
  Widget build(BuildContext context) {
    return _TooltipVisibilityScope(
      visible: visible,
      child: child,
    );
  }
}