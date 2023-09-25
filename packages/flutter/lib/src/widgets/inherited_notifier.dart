
import 'package:flutter/foundation.dart';

import 'framework.dart';

abstract class InheritedNotifier<T extends Listenable> extends InheritedWidget {
  const InheritedNotifier({
    super.key,
    this.notifier,
    required super.child,
  });

  final T? notifier;

  @override
  bool updateShouldNotify(InheritedNotifier<T> oldWidget) {
    return oldWidget.notifier != notifier;
  }

  @override
  InheritedElement createElement() => _InheritedNotifierElement<T>(this);
}

class _InheritedNotifierElement<T extends Listenable> extends InheritedElement {
  _InheritedNotifierElement(InheritedNotifier<T> widget) : super(widget) {
    widget.notifier?.addListener(_handleUpdate);
  }

  bool _dirty = false;

  @override
  void update(InheritedNotifier<T> newWidget) {
    final T? oldNotifier = (widget as InheritedNotifier<T>).notifier;
    final T? newNotifier = newWidget.notifier;
    if (oldNotifier != newNotifier) {
      oldNotifier?.removeListener(_handleUpdate);
      newNotifier?.addListener(_handleUpdate);
    }
    super.update(newWidget);
  }

  @override
  Widget build() {
    if (_dirty) {
      notifyClients(widget as InheritedNotifier<T>);
    }
    return super.build();
  }

  void _handleUpdate() {
    _dirty = true;
    markNeedsBuild();
  }

  @override
  void notifyClients(InheritedNotifier<T> oldWidget) {
    super.notifyClients(oldWidget);
    _dirty = false;
  }

  @override
  void unmount() {
    (widget as InheritedNotifier<T>).notifier?.removeListener(_handleUpdate);
    super.unmount();
  }
}