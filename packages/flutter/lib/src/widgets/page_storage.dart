
import 'package:flutter/foundation.dart';

import 'framework.dart';

// Examples can assume:
// late BuildContext context;

class PageStorageKey<T> extends ValueKey<T> {
  const PageStorageKey(super.value);
}

@immutable
class _StorageEntryIdentifier {
  const _StorageEntryIdentifier(this.keys);

  final List<PageStorageKey<dynamic>> keys;

  bool get isNotEmpty => keys.isNotEmpty;

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is _StorageEntryIdentifier
        && listEquals<PageStorageKey<dynamic>>(other.keys, keys);
  }

  @override
  int get hashCode => Object.hashAll(keys);

  @override
  String toString() {
    return 'StorageEntryIdentifier(${keys.join(":")})';
  }
}

class PageStorageBucket {
  static bool _maybeAddKey(BuildContext context, List<PageStorageKey<dynamic>> keys) {
    final Widget widget = context.widget;
    final Key? key = widget.key;
    if (key is PageStorageKey) {
      keys.add(key);
    }
    return widget is! PageStorage;
  }

  List<PageStorageKey<dynamic>> _allKeys(BuildContext context) {
    final List<PageStorageKey<dynamic>> keys = <PageStorageKey<dynamic>>[];
    if (_maybeAddKey(context, keys)) {
      context.visitAncestorElements((Element element) {
        return _maybeAddKey(element, keys);
      });
    }
    return keys;
  }

  _StorageEntryIdentifier _computeIdentifier(BuildContext context) {
    return _StorageEntryIdentifier(_allKeys(context));
  }

  Map<Object, dynamic>? _storage;

  void writeState(BuildContext context, dynamic data, { Object? identifier }) {
    _storage ??= <Object, dynamic>{};
    if (identifier != null) {
      _storage![identifier] = data;
    } else {
      final _StorageEntryIdentifier contextIdentifier = _computeIdentifier(context);
      if (contextIdentifier.isNotEmpty) {
        _storage![contextIdentifier] = data;
      }
    }
  }

  dynamic readState(BuildContext context, { Object? identifier }) {
    if (_storage == null) {
      return null;
    }
    if (identifier != null) {
      return _storage![identifier];
    }
    final _StorageEntryIdentifier contextIdentifier = _computeIdentifier(context);
    return contextIdentifier.isNotEmpty ? _storage![contextIdentifier] : null;
  }
}

class PageStorage extends StatelessWidget {
  const PageStorage({
    super.key,
    required this.bucket,
    required this.child,
  });

  final Widget child;

  final PageStorageBucket bucket;

  static PageStorageBucket? maybeOf(BuildContext context) {
    final PageStorage? widget = context.findAncestorWidgetOfExactType<PageStorage>();
    return widget?.bucket;
  }

  static PageStorageBucket of(BuildContext context) {
    final PageStorageBucket? bucket = maybeOf(context);
    assert(() {
      if (bucket == null) {
        throw FlutterError(
          'PageStorage.of() was called with a context that does not contain a '
          'PageStorage widget.\n'
          'No PageStorage widget ancestor could be found starting from the '
          'context that was passed to PageStorage.of(). This can happen '
          'because you are using a widget that looks for a PageStorage '
          'ancestor, but no such ancestor exists.\n'
          'The context used was:\n'
          '  $context',
        );
      }
      return true;
    }());
    return bucket!;
  }

  @override
  Widget build(BuildContext context) => child;
}