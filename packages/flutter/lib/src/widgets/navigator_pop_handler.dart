
import 'framework.dart';
import 'navigator.dart';
import 'notification_listener.dart';
import 'pop_scope.dart';

class NavigatorPopHandler extends StatefulWidget {
  const NavigatorPopHandler({
    super.key,
    this.onPop,
    this.enabled = true,
    required this.child,
  });

  final Widget child;

  final bool enabled;

  final VoidCallback? onPop;

  @override
  State<NavigatorPopHandler> createState() => _NavigatorPopHandlerState();
}

class _NavigatorPopHandlerState extends State<NavigatorPopHandler> {
  bool _canPop = true;

  @override
  Widget build(BuildContext context) {
    // When the widget subtree indicates it can handle a pop, disable popping
    // here, so that it can be manually handled in canPop.
    return PopScope(
      canPop: !widget.enabled || _canPop,
      onPopInvoked: (bool didPop) {
        if (didPop) {
          return;
        }
        widget.onPop?.call();
      },
      // Listen to changes in the navigation stack in the widget subtree.
      child: NotificationListener<NavigationNotification>(
        onNotification: (NavigationNotification notification) {
          // If this subtree cannot handle pop, then set canPop to true so
          // that our PopScope will allow the Navigator higher in the tree to
          // handle the pop instead.
          final bool nextCanPop = !notification.canHandlePop;
          if (nextCanPop != _canPop) {
            setState(() {
              _canPop = nextCanPop;
            });
          }
          return false;
        },
        child: widget.child,
      ),
    );
  }
}