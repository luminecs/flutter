import 'package:flutter/foundation.dart';

import 'framework.dart';

typedef NotificationListenerCallback<T extends Notification> = bool Function(
    T notification);

abstract class Notification {
  const Notification();

  void dispatch(BuildContext? target) {
    target?.dispatchNotification(this);
  }

  @override
  String toString() {
    final List<String> description = <String>[];
    debugFillDescription(description);
    return '${objectRuntimeType(this, 'Notification')}(${description.join(", ")})';
  }

  @protected
  @mustCallSuper
  void debugFillDescription(List<String> description) {}
}

class NotificationListener<T extends Notification> extends ProxyWidget {
  const NotificationListener({
    super.key,
    required super.child,
    this.onNotification,
  });

  final NotificationListenerCallback<T>? onNotification;

  @override
  Element createElement() {
    return _NotificationElement<T>(this);
  }
}

class _NotificationElement<T extends Notification> extends ProxyElement
    with NotifiableElementMixin {
  _NotificationElement(NotificationListener<T> super.widget);

  @override
  bool onNotification(Notification notification) {
    final NotificationListener<T> listener = widget as NotificationListener<T>;
    if (listener.onNotification != null && notification is T) {
      return listener.onNotification!(notification);
    }
    return false;
  }

  @override
  void notifyClients(covariant ProxyWidget oldWidget) {
    // Notification tree does not need to notify clients.
  }
}

class LayoutChangedNotification extends Notification {
  const LayoutChangedNotification();
}
