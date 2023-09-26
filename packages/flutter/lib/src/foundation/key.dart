import 'package:meta/meta.dart';

import 'diagnostics.dart';

@immutable
abstract class Key {
  const factory Key(String value) = ValueKey<String>;

  @protected
  const Key.empty();
}

abstract class LocalKey extends Key {
  const LocalKey() : super.empty();
}

class UniqueKey extends LocalKey {
  // ignore: prefer_const_constructors_in_immutables , never use const for this class
  UniqueKey();

  @override
  String toString() => '[#${shortHash(this)}]';
}

class ValueKey<T> extends LocalKey {
  const ValueKey(this.value);

  final T value;

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is ValueKey<T> && other.value == value;
  }

  @override
  int get hashCode => Object.hash(runtimeType, value);

  @override
  String toString() {
    final String valueString = T == String ? "<'$value'>" : '<$value>';
    // The crazy on the next line is a workaround for
    // https://github.com/dart-lang/sdk/issues/33297
    if (runtimeType == _TypeLiteral<ValueKey<T>>().type) {
      return '[$valueString]';
    }
    return '[$T $valueString]';
  }
}

class _TypeLiteral<T> {
  Type get type => T;
}
