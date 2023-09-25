
import 'dart:async';
import 'dart:collection';

import 'package:meta/meta.dart';

typedef Generator = dynamic Function();

class ContextDependencyCycleException implements Exception {
  ContextDependencyCycleException._(this.cycle);

  final List<Type> cycle;

  @override
  String toString() => 'Dependency cycle detected: ${cycle.join(' -> ')}';
}

@visibleForTesting
const Object contextKey = _Key.key;

AppContext get context => Zone.current[contextKey] as AppContext? ?? AppContext._root;

class AppContext {
  AppContext._(
    this._parent,
    this.name, [
    this._overrides = const <Type, Generator>{},
    this._fallbacks = const <Type, Generator>{},
  ]);

  final String? name;
  final AppContext? _parent;
  final Map<Type, Generator> _overrides;
  final Map<Type, Generator> _fallbacks;
  final Map<Type, dynamic> _values = <Type, dynamic>{};

  List<Type>? _reentrantChecks;

  static final AppContext _root = AppContext._(null, 'ROOT');

  dynamic _boxNull(dynamic value) => value ?? _BoxedNull.instance;

  dynamic _unboxNull(dynamic value) => value == _BoxedNull.instance ? null : value;

  dynamic _generateIfNecessary(Type type, Map<Type, Generator> generators) {
    if (!generators.containsKey(type)) {
      return null;
    }

    return _values.putIfAbsent(type, () {
      _reentrantChecks ??= <Type>[];

      final int index = _reentrantChecks!.indexOf(type);
      if (index >= 0) {
        // We're already in the process of trying to generate this type.
        throw ContextDependencyCycleException._(
            UnmodifiableListView<Type>(_reentrantChecks!.sublist(index)));
      }

      _reentrantChecks!.add(type);
      try {
        return _boxNull(generators[type]!());
      } finally {
        _reentrantChecks!.removeLast();
        if (_reentrantChecks!.isEmpty) {
          _reentrantChecks = null;
        }
      }
    });
  }

  T? get<T>() {
    dynamic value = _generateIfNecessary(T, _overrides);
    if (value == null && _parent != null) {
      value = _parent.get<T>();
    }
    return _unboxNull(value ?? _generateIfNecessary(T, _fallbacks)) as T?;
  }

  Future<V> run<V>({
    required FutureOr<V> Function() body,
    String? name,
    Map<Type, Generator>? overrides,
    Map<Type, Generator>? fallbacks,
    ZoneSpecification? zoneSpecification,
  }) async {
    final AppContext child = AppContext._(
      this,
      name,
      Map<Type, Generator>.unmodifiable(overrides ?? const <Type, Generator>{}),
      Map<Type, Generator>.unmodifiable(fallbacks ?? const <Type, Generator>{}),
    );
    return runZoned<Future<V>>(
      () async => await body(),
      zoneValues: <_Key, AppContext>{_Key.key: child},
      zoneSpecification: zoneSpecification,
    );
  }

  @override
  String toString() {
    final StringBuffer buf = StringBuffer();
    String indent = '';
    AppContext? ctx = this;
    while (ctx != null) {
      buf.write('AppContext');
      if (ctx.name != null) {
        buf.write('[${ctx.name}]');
      }
      if (ctx._overrides.isNotEmpty) {
        buf.write('\n$indent  overrides: [${ctx._overrides.keys.join(', ')}]');
      }
      if (ctx._fallbacks.isNotEmpty) {
        buf.write('\n$indent  fallbacks: [${ctx._fallbacks.keys.join(', ')}]');
      }
      if (ctx._parent != null) {
        buf.write('\n$indent  parent: ');
      }
      ctx = ctx._parent;
      indent += '  ';
    }
    return buf.toString();
  }
}

class _Key {
  const _Key();

  static const _Key key = _Key();

  @override
  String toString() => 'context';
}

class _BoxedNull {
  const _BoxedNull();

  static const _BoxedNull instance = _BoxedNull();
}