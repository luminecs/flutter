import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'input_border.dart';

// Examples can assume:
// late BuildContext context;

enum MaterialState {
  hovered,

  focused,

  pressed,

  dragged,

  selected,

  scrolledUnder,

  disabled,

  error,
}

typedef MaterialPropertyResolver<T> = T Function(Set<MaterialState> states);

abstract class MaterialStateColor extends Color
    implements MaterialStateProperty<Color> {
  const MaterialStateColor(super.defaultValue);

  static MaterialStateColor resolveWith(
          MaterialPropertyResolver<Color> callback) =>
      _MaterialStateColor(callback);

  @override
  Color resolve(Set<MaterialState> states);
}

class _MaterialStateColor extends MaterialStateColor {
  _MaterialStateColor(this._resolve) : super(_resolve(_defaultStates).value);

  final MaterialPropertyResolver<Color> _resolve;

  static const Set<MaterialState> _defaultStates = <MaterialState>{};

  @override
  Color resolve(Set<MaterialState> states) => _resolve(states);
}

abstract class MaterialStateMouseCursor extends MouseCursor
    implements MaterialStateProperty<MouseCursor> {
  const MaterialStateMouseCursor();

  @protected
  @override
  MouseCursorSession createSession(int device) {
    return resolve(<MaterialState>{}).createSession(device);
  }

  @override
  MouseCursor resolve(Set<MaterialState> states);

  static const MaterialStateMouseCursor clickable =
      _EnabledAndDisabledMouseCursor(
    enabledCursor: SystemMouseCursors.click,
    disabledCursor: SystemMouseCursors.basic,
    name: 'clickable',
  );

  static const MaterialStateMouseCursor textable =
      _EnabledAndDisabledMouseCursor(
    enabledCursor: SystemMouseCursors.text,
    disabledCursor: SystemMouseCursors.basic,
    name: 'textable',
  );
}

class _EnabledAndDisabledMouseCursor extends MaterialStateMouseCursor {
  const _EnabledAndDisabledMouseCursor({
    required this.enabledCursor,
    required this.disabledCursor,
    required this.name,
  });

  final MouseCursor enabledCursor;
  final MouseCursor disabledCursor;
  final String name;

  @override
  MouseCursor resolve(Set<MaterialState> states) {
    if (states.contains(MaterialState.disabled)) {
      return disabledCursor;
    }
    return enabledCursor;
  }

  @override
  String get debugDescription => 'MaterialStateMouseCursor($name)';
}

abstract class MaterialStateBorderSide extends BorderSide
    implements MaterialStateProperty<BorderSide?> {
  const MaterialStateBorderSide();

  @override
  BorderSide? resolve(Set<MaterialState> states);

  static MaterialStateBorderSide resolveWith(
          MaterialPropertyResolver<BorderSide?> callback) =>
      _MaterialStateBorderSide(callback);
}

class _MaterialStateBorderSide extends MaterialStateBorderSide {
  const _MaterialStateBorderSide(this._resolve);

  final MaterialPropertyResolver<BorderSide?> _resolve;

  @override
  BorderSide? resolve(Set<MaterialState> states) {
    return _resolve(states);
  }
}

abstract class MaterialStateOutlinedBorder extends OutlinedBorder
    implements MaterialStateProperty<OutlinedBorder?> {
  const MaterialStateOutlinedBorder();

  @override
  OutlinedBorder? resolve(Set<MaterialState> states);
}

abstract class MaterialStateTextStyle extends TextStyle
    implements MaterialStateProperty<TextStyle> {
  const MaterialStateTextStyle();

  static MaterialStateTextStyle resolveWith(
          MaterialPropertyResolver<TextStyle> callback) =>
      _MaterialStateTextStyle(callback);

  @override
  TextStyle resolve(Set<MaterialState> states);
}

class _MaterialStateTextStyle extends MaterialStateTextStyle {
  const _MaterialStateTextStyle(this._resolve);

  final MaterialPropertyResolver<TextStyle> _resolve;

  @override
  TextStyle resolve(Set<MaterialState> states) => _resolve(states);
}

abstract class MaterialStateOutlineInputBorder extends OutlineInputBorder
    implements MaterialStateProperty<InputBorder> {
  const MaterialStateOutlineInputBorder();

  static MaterialStateOutlineInputBorder resolveWith(
          MaterialPropertyResolver<InputBorder> callback) =>
      _MaterialStateOutlineInputBorder(callback);

  @override
  InputBorder resolve(Set<MaterialState> states);
}

class _MaterialStateOutlineInputBorder extends MaterialStateOutlineInputBorder {
  const _MaterialStateOutlineInputBorder(this._resolve);

  final MaterialPropertyResolver<InputBorder> _resolve;

  @override
  InputBorder resolve(Set<MaterialState> states) => _resolve(states);
}

abstract class MaterialStateUnderlineInputBorder extends UnderlineInputBorder
    implements MaterialStateProperty<InputBorder> {
  const MaterialStateUnderlineInputBorder();

  static MaterialStateUnderlineInputBorder resolveWith(
          MaterialPropertyResolver<InputBorder> callback) =>
      _MaterialStateUnderlineInputBorder(callback);

  @override
  InputBorder resolve(Set<MaterialState> states);
}

class _MaterialStateUnderlineInputBorder
    extends MaterialStateUnderlineInputBorder {
  const _MaterialStateUnderlineInputBorder(this._resolve);

  final MaterialPropertyResolver<InputBorder> _resolve;

  @override
  InputBorder resolve(Set<MaterialState> states) => _resolve(states);
}

abstract class MaterialStateProperty<T> {
  T resolve(Set<MaterialState> states);

  static T resolveAs<T>(T value, Set<MaterialState> states) {
    if (value is MaterialStateProperty<T>) {
      final MaterialStateProperty<T> property = value;
      return property.resolve(states);
    }
    return value;
  }

  static MaterialStateProperty<T> resolveWith<T>(
          MaterialPropertyResolver<T> callback) =>
      _MaterialStatePropertyWith<T>(callback);

  // TODO(darrenaustin): Deprecate this when we have the ability to create
  // a dart fix that will replace this with MaterialStatePropertyAll:
  // https://github.com/dart-lang/sdk/issues/49056.
  static MaterialStateProperty<T> all<T>(T value) =>
      MaterialStatePropertyAll<T>(value);

  static MaterialStateProperty<T?>? lerp<T>(
    MaterialStateProperty<T>? a,
    MaterialStateProperty<T>? b,
    double t,
    T? Function(T?, T?, double) lerpFunction,
  ) {
    // Avoid creating a _LerpProperties object for a common case.
    if (a == null && b == null) {
      return null;
    }
    return _LerpProperties<T>(a, b, t, lerpFunction);
  }
}

class _LerpProperties<T> implements MaterialStateProperty<T?> {
  const _LerpProperties(this.a, this.b, this.t, this.lerpFunction);

  final MaterialStateProperty<T>? a;
  final MaterialStateProperty<T>? b;
  final double t;
  final T? Function(T?, T?, double) lerpFunction;

  @override
  T? resolve(Set<MaterialState> states) {
    final T? resolvedA = a?.resolve(states);
    final T? resolvedB = b?.resolve(states);
    return lerpFunction(resolvedA, resolvedB, t);
  }
}

class _MaterialStatePropertyWith<T> implements MaterialStateProperty<T> {
  _MaterialStatePropertyWith(this._resolve);

  final MaterialPropertyResolver<T> _resolve;

  @override
  T resolve(Set<MaterialState> states) => _resolve(states);
}

class MaterialStatePropertyAll<T> implements MaterialStateProperty<T> {
  const MaterialStatePropertyAll(this.value);

  final T value;

  @override
  T resolve(Set<MaterialState> states) => value;

  @override
  String toString() {
    if (value is double) {
      return 'MaterialStatePropertyAll(${debugFormatDouble(value as double)})';
    } else {
      return 'MaterialStatePropertyAll($value)';
    }
  }
}

class MaterialStatesController extends ValueNotifier<Set<MaterialState>> {
  MaterialStatesController([Set<MaterialState>? value])
      : super(<MaterialState>{...?value});

  void update(MaterialState state, bool add) {
    final bool valueChanged = add ? value.add(state) : value.remove(state);
    if (valueChanged) {
      notifyListeners();
    }
  }
}
