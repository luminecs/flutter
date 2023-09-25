import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'editable_text.dart';
import 'restoration.dart';

abstract class RestorableValue<T> extends RestorableProperty<T> {
  T get value {
    assert(isRegistered);
    return _value as T;
  }
  T? _value;
  set value(T newValue) {
    assert(isRegistered);
    if (newValue != _value) {
      final T? oldValue = _value;
      _value = newValue;
      didUpdateValue(oldValue);
    }
  }

  @mustCallSuper
  @override
  void initWithValue(T value) {
    _value = value;
  }

  @protected
  void didUpdateValue(T? oldValue);
}

// _RestorablePrimitiveValueN and its subclasses allows for null values.
// See [_RestorablePrimitiveValue] for the non-nullable version of this class.
class _RestorablePrimitiveValueN<T extends Object?> extends RestorableValue<T> {
  _RestorablePrimitiveValueN(this._defaultValue)
    : assert(debugIsSerializableForRestoration(_defaultValue)),
      super();

  final T _defaultValue;

  @override
  T createDefaultValue() => _defaultValue;

  @override
  void didUpdateValue(T? oldValue) {
    assert(debugIsSerializableForRestoration(value));
    notifyListeners();
  }

  @override
  T fromPrimitives(Object? serialized) => serialized as T;

  @override
  Object? toPrimitives() => value;
}

// _RestorablePrimitiveValue and its subclasses are non-nullable.
// See [_RestorablePrimitiveValueN] for the nullable version of this class.
class _RestorablePrimitiveValue<T extends Object> extends _RestorablePrimitiveValueN<T> {
  _RestorablePrimitiveValue(super.defaultValue)
    : assert(debugIsSerializableForRestoration(defaultValue));

  @override
  set value(T value) {
    super.value = value;
  }

  @override
  T fromPrimitives(Object? serialized) {
    assert(serialized != null);
    return super.fromPrimitives(serialized);
  }

  @override
  Object toPrimitives() {
    return super.toPrimitives()!;
  }
}

class RestorableNum<T extends num> extends _RestorablePrimitiveValue<T> {
  RestorableNum(super.defaultValue);
}

class RestorableDouble extends RestorableNum<double> {
  RestorableDouble(super.defaultValue);
}

class RestorableInt extends RestorableNum<int> {
  RestorableInt(super.defaultValue);
}

class RestorableString extends _RestorablePrimitiveValue<String> {
  RestorableString(super.defaultValue);
}

class RestorableBool extends _RestorablePrimitiveValue<bool> {
  RestorableBool(super.defaultValue);
}

class RestorableBoolN extends _RestorablePrimitiveValueN<bool?> {
  RestorableBoolN(super.defaultValue);
}

class RestorableNumN<T extends num?> extends _RestorablePrimitiveValueN<T> {
  RestorableNumN(super.defaultValue);
}

class RestorableDoubleN extends RestorableNumN<double?> {
  RestorableDoubleN(super.defaultValue);
}

class RestorableIntN extends RestorableNumN<int?> {
  RestorableIntN(super.defaultValue);
}

class RestorableStringN extends _RestorablePrimitiveValueN<String?> {
  RestorableStringN(super.defaultValue);
}

class RestorableDateTime extends RestorableValue<DateTime> {
  RestorableDateTime(DateTime defaultValue) : _defaultValue = defaultValue;

  final DateTime _defaultValue;

  @override
  DateTime createDefaultValue() => _defaultValue;

  @override
  void didUpdateValue(DateTime? oldValue) {
    assert(debugIsSerializableForRestoration(value.millisecondsSinceEpoch));
    notifyListeners();
  }

  @override
  DateTime fromPrimitives(Object? data) => DateTime.fromMillisecondsSinceEpoch(data! as int);

  @override
  Object? toPrimitives() => value.millisecondsSinceEpoch;
}

class RestorableDateTimeN extends RestorableValue<DateTime?> {
  RestorableDateTimeN(DateTime? defaultValue) : _defaultValue = defaultValue;

  final DateTime? _defaultValue;

  @override
  DateTime? createDefaultValue() => _defaultValue;

  @override
  void didUpdateValue(DateTime? oldValue) {
    assert(debugIsSerializableForRestoration(value?.millisecondsSinceEpoch));
    notifyListeners();
  }

  @override
  DateTime? fromPrimitives(Object? data) => data != null ? DateTime.fromMillisecondsSinceEpoch(data as int) : null;

  @override
  Object? toPrimitives() => value?.millisecondsSinceEpoch;
}

abstract class RestorableListenable<T extends Listenable> extends RestorableProperty<T> {
  T get value {
    assert(isRegistered);
    return _value!;
  }
  T? _value;

  @override
  void initWithValue(T value) {
    _value?.removeListener(notifyListeners);
    _value = value;
    _value!.addListener(notifyListeners);
  }

  @override
  void dispose() {
    super.dispose();
    _value?.removeListener(notifyListeners);
  }
}

abstract class RestorableChangeNotifier<T extends ChangeNotifier> extends RestorableListenable<T> {
  @override
  void initWithValue(T value) {
    _disposeOldValue();
    super.initWithValue(value);
  }

  @override
  void dispose() {
    _disposeOldValue();
    super.dispose();
  }

  void _disposeOldValue() {
    if (_value != null) {
      // Scheduling a microtask for dispose to give other entities a chance
      // to remove their listeners first.
      scheduleMicrotask(_value!.dispose);
    }
  }
}

class RestorableTextEditingController extends RestorableChangeNotifier<TextEditingController> {
  factory RestorableTextEditingController({String? text}) => RestorableTextEditingController.fromValue(
    text == null ? TextEditingValue.empty : TextEditingValue(text: text),
  );

  RestorableTextEditingController.fromValue(TextEditingValue value) : _initialValue = value;

  final TextEditingValue _initialValue;

  @override
  TextEditingController createDefaultValue() {
    return TextEditingController.fromValue(_initialValue);
  }

  @override
  TextEditingController fromPrimitives(Object? data) {
    return TextEditingController(text: data! as String);
  }

  @override
  Object toPrimitives() {
    return value.text;
  }
}

class RestorableEnumN<T extends Enum> extends RestorableValue<T?> {
  RestorableEnumN(T? defaultValue, { required Iterable<T> values })
    : assert(defaultValue == null || values.contains(defaultValue),
        'Default value $defaultValue not found in $T values: $values'),
      _defaultValue = defaultValue,
      values = values.toSet();

  @override
  T? createDefaultValue() => _defaultValue;
  final T? _defaultValue;

  @override
  set value(T? newValue) {
    assert(newValue == null || values.contains(newValue),
      'Attempted to set an unknown enum value "$newValue" that is not null, or '
      'in the valid set of enum values for the $T type: '
      '${values.map<String>((T value) => value.name).toSet()}');
    super.value = newValue;
  }

  Set<T> values;

  @override
  void didUpdateValue(T? oldValue) {
    notifyListeners();
  }

  @override
  T? fromPrimitives(Object? data) {
    if (data == null) {
      return null;
    }
    if (data is String) {
      for (final T allowed in values) {
        if (allowed.name == data) {
          return allowed;
        }
      }
      assert(false,
        'Attempted to set an unknown enum value "$data" that is not null, or '
        'in the valid set of enum values for the $T type: '
        '${values.map<String>((T value) => value.name).toSet()}');
    }
    return _defaultValue;
  }

  @override
  Object? toPrimitives() => value?.name;
}


class RestorableEnum<T extends Enum> extends RestorableValue<T> {
  RestorableEnum(T defaultValue, { required Iterable<T> values })
    : assert(values.contains(defaultValue),
        'Default value $defaultValue not found in $T values: $values'),
      _defaultValue = defaultValue,
      values = values.toSet();

  @override
  T createDefaultValue() => _defaultValue;
  final T _defaultValue;

  @override
  set value(T newValue) {
    assert(values.contains(newValue),
      'Attempted to set an unknown enum value "$newValue" that is not in the '
      'valid set of enum values for the $T type: '
      '${values.map<String>((T value) => value.name).toSet()}');

    super.value = newValue;
  }

  Set<T> values;

  @override
  void didUpdateValue(T? oldValue) {
    notifyListeners();
  }

  @override
  T fromPrimitives(Object? data) {
    if (data != null && data is String) {
      for (final T allowed in values) {
        if (allowed.name == data) {
          return allowed;
        }
      }
      assert(false,
        'Attempted to restore an unknown enum value "$data" that is not in the '
        'valid set of enum values for the $T type: '
        '${values.map<String>((T value) => value.name).toSet()}');
    }
    return _defaultValue;
  }

  @override
  Object toPrimitives() => value.name;
}