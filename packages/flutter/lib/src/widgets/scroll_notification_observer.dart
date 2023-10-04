import 'dart:collection';

import 'package:flutter/foundation.dart';

import 'framework.dart';
import 'notification_listener.dart';
import 'scroll_notification.dart';
import 'scroll_position.dart';

// Examples can assume:
// void _listener(ScrollNotification notification) { }
// late BuildContext context;

typedef ScrollNotificationCallback = void Function(
    ScrollNotification notification);

class _ScrollNotificationObserverScope extends InheritedWidget {
  const _ScrollNotificationObserverScope({
    required super.child,
    required ScrollNotificationObserverState scrollNotificationObserverState,
  }) : _scrollNotificationObserverState = scrollNotificationObserverState;

  final ScrollNotificationObserverState _scrollNotificationObserverState;

  @override
  bool updateShouldNotify(_ScrollNotificationObserverScope old) =>
      _scrollNotificationObserverState != old._scrollNotificationObserverState;
}

final class _ListenerEntry extends LinkedListEntry<_ListenerEntry> {
  _ListenerEntry(this.listener);
  final ScrollNotificationCallback listener;
}

class ScrollNotificationObserver extends StatefulWidget {
  const ScrollNotificationObserver({
    super.key,
    required this.child,
  });

  final Widget child;

  static ScrollNotificationObserverState? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_ScrollNotificationObserverScope>()
        ?._scrollNotificationObserverState;
  }

  static ScrollNotificationObserverState of(BuildContext context) {
    final ScrollNotificationObserverState? observerState = maybeOf(context);
    assert(() {
      if (observerState == null) {
        throw FlutterError(
          'ScrollNotificationObserver.of() was called with a context that does not contain a '
          'ScrollNotificationObserver widget.\n'
          'No ScrollNotificationObserver widget ancestor could be found starting from the '
          'context that was passed to ScrollNotificationObserver.of(). This can happen '
          'because you are using a widget that looks for a ScrollNotificationObserver '
          'ancestor, but no such ancestor exists.\n'
          'The context used was:\n'
          '  $context',
        );
      }
      return true;
    }());
    return observerState!;
  }

  @override
  ScrollNotificationObserverState createState() =>
      ScrollNotificationObserverState();
}

class ScrollNotificationObserverState
    extends State<ScrollNotificationObserver> {
  LinkedList<_ListenerEntry>? _listeners = LinkedList<_ListenerEntry>();

  bool _debugAssertNotDisposed() {
    assert(() {
      if (_listeners == null) {
        throw FlutterError(
          'A $runtimeType was used after being disposed.\n'
          'Once you have called dispose() on a $runtimeType, it can no longer be used.',
        );
      }
      return true;
    }());
    return true;
  }

  void addListener(ScrollNotificationCallback listener) {
    assert(_debugAssertNotDisposed());
    _listeners!.add(_ListenerEntry(listener));
  }

  void removeListener(ScrollNotificationCallback listener) {
    assert(_debugAssertNotDisposed());
    for (final _ListenerEntry entry in _listeners!) {
      if (entry.listener == listener) {
        entry.unlink();
        return;
      }
    }
  }

  void _notifyListeners(ScrollNotification notification) {
    assert(_debugAssertNotDisposed());
    if (_listeners!.isEmpty) {
      return;
    }

    final List<_ListenerEntry> localListeners =
        List<_ListenerEntry>.of(_listeners!);
    for (final _ListenerEntry entry in localListeners) {
      try {
        if (entry.list != null) {
          entry.listener(notification);
        }
      } catch (exception, stack) {
        FlutterError.reportError(FlutterErrorDetails(
          exception: exception,
          stack: stack,
          library: 'widget library',
          context: ErrorDescription(
              'while dispatching notifications for $runtimeType'),
          informationCollector: () => <DiagnosticsNode>[
            DiagnosticsProperty<ScrollNotificationObserverState>(
              'The $runtimeType sending notification was',
              this,
              style: DiagnosticsTreeStyle.errorProperty,
            ),
          ],
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollMetricsNotification>(
      onNotification: (ScrollMetricsNotification notification) {
        // A ScrollMetricsNotification allows listeners to be notified for an
        // initial state, as well as if the content dimensions change without
        // scrolling.
        _notifyListeners(notification.asScrollUpdate());
        return false;
      },
      child: NotificationListener<ScrollNotification>(
        onNotification: (ScrollNotification notification) {
          _notifyListeners(notification);
          return false;
        },
        child: _ScrollNotificationObserverScope(
          scrollNotificationObserverState: this,
          child: widget.child,
        ),
      ),
    );
  }

  @override
  void dispose() {
    assert(_debugAssertNotDisposed());
    _listeners = null;
    super.dispose();
  }
}
