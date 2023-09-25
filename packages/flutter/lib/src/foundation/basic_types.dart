
import 'dart:collection';

// COMMON SIGNATURES

typedef ValueChanged<T> = void Function(T value);

typedef ValueSetter<T> = void Function(T value);

typedef ValueGetter<T> = T Function();

typedef IterableFilter<T> = Iterable<T> Function(Iterable<T> input);

typedef AsyncCallback = Future<void> Function();

typedef AsyncValueSetter<T> = Future<void> Function(T value);

typedef AsyncValueGetter<T> = Future<T> Function();

// LAZY CACHING ITERATOR

class CachingIterable<E> extends IterableBase<E> {
  CachingIterable(this._prefillIterator);

  final Iterator<E> _prefillIterator;
  final List<E> _results = <E>[];

  @override
  Iterator<E> get iterator {
    return _LazyListIterator<E>(this);
  }

  @override
  Iterable<T> map<T>(T Function(E e) toElement) {
    return CachingIterable<T>(super.map<T>(toElement).iterator);
  }

  @override
  Iterable<E> where(bool Function(E element) test) {
    return CachingIterable<E>(super.where(test).iterator);
  }

  @override
  Iterable<T> expand<T>(Iterable<T> Function(E element) toElements) {
    return CachingIterable<T>(super.expand<T>(toElements).iterator);
  }

  @override
  Iterable<E> take(int count) {
    return CachingIterable<E>(super.take(count).iterator);
  }

  @override
  Iterable<E> takeWhile(bool Function(E value) test) {
    return CachingIterable<E>(super.takeWhile(test).iterator);
  }

  @override
  Iterable<E> skip(int count) {
    return CachingIterable<E>(super.skip(count).iterator);
  }

  @override
  Iterable<E> skipWhile(bool Function(E value) test) {
    return CachingIterable<E>(super.skipWhile(test).iterator);
  }

  @override
  int get length {
    _precacheEntireList();
    return _results.length;
  }

  @override
  List<E> toList({ bool growable = true }) {
    _precacheEntireList();
    return List<E>.of(_results, growable: growable);
  }

  void _precacheEntireList() {
    while (_fillNext()) { }
  }

  bool _fillNext() {
    if (!_prefillIterator.moveNext()) {
      return false;
    }
    _results.add(_prefillIterator.current);
    return true;
  }
}

class _LazyListIterator<E> implements Iterator<E> {
  _LazyListIterator(this._owner) : _index = -1;

  final CachingIterable<E> _owner;
  int _index;

  @override
  E get current {
    assert(_index >= 0); // called "current" before "moveNext()"
    if (_index < 0 || _index == _owner._results.length) {
      throw StateError('current can not be call after moveNext has returned false');
    }
    return _owner._results[_index];
  }

  @override
  bool moveNext() {
    if (_index >= _owner._results.length) {
      return false;
    }
    _index += 1;
    if (_index == _owner._results.length) {
      return _owner._fillNext();
    }
    return true;
  }
}

class Factory<T> {
  const Factory(this.constructor);

  final ValueGetter<T> constructor;

  Type get type => T;

  @override
  String toString() {
    return 'Factory(type: $type)';
  }
}

Duration lerpDuration(Duration a, Duration b, double t) {
  return Duration(
    microseconds: (a.inMicroseconds + (b.inMicroseconds - a.inMicroseconds) * t).round(),
  );
}