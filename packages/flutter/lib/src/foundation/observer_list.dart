import 'dart:collection';

// TODO(ianh): Use DelegatingIterable, possibly moving it from the collection
// package to foundation, or to dart:collection.
class ObserverList<T> extends Iterable<T> {
  final List<T> _list = <T>[];
  bool _isDirty = false;
  late final HashSet<T> _set = HashSet<T>();

  void add(T item) {
    _isDirty = true;
    _list.add(item);
  }

  bool remove(T item) {
    _isDirty = true;
    _set.clear(); // Clear the set so that we don't leak items.
    return _list.remove(item);
  }

  void clear() {
    _isDirty = false;
    _list.clear();
    _set.clear();
  }

  @override
  bool contains(Object? element) {
    if (_list.length < 3) {
      return _list.contains(element);
    }

    if (_isDirty) {
      _set.addAll(_list);
      _isDirty = false;
    }

    return _set.contains(element);
  }

  @override
  Iterator<T> get iterator => _list.iterator;

  @override
  bool get isEmpty => _list.isEmpty;

  @override
  bool get isNotEmpty => _list.isNotEmpty;

  @override
  List<T> toList({bool growable = true}) {
    return _list.toList(growable: growable);
  }
}

class HashedObserverList<T> extends Iterable<T> {
  final LinkedHashMap<T, int> _map = LinkedHashMap<T, int>();

  void add(T item) {
    _map[item] = (_map[item] ?? 0) + 1;
  }

  bool remove(T item) {
    final int? value = _map[item];
    if (value == null) {
      return false;
    }
    if (value == 1) {
      _map.remove(item);
    } else {
      _map[item] = value - 1;
    }
    return true;
  }

  @override
  bool contains(Object? element) => _map.containsKey(element);

  @override
  Iterator<T> get iterator => _map.keys.iterator;

  @override
  bool get isEmpty => _map.isEmpty;

  @override
  bool get isNotEmpty => _map.isNotEmpty;
}
