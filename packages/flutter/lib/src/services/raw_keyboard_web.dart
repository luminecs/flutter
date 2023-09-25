import 'package:flutter/foundation.dart';

import 'keyboard_maps.g.dart';
import 'raw_keyboard.dart';

export 'package:flutter/foundation.dart' show DiagnosticPropertiesBuilder;

export 'keyboard_key.g.dart' show LogicalKeyboardKey, PhysicalKeyboardKey;
export 'raw_keyboard.dart' show KeyboardSide, ModifierKey;

String? _unicodeChar(String key) {
  if (key.length == 1) {
    return key.substring(0, 1);
  }
  return null;
}

@immutable
class RawKeyEventDataWeb extends RawKeyEventData {
  const RawKeyEventDataWeb({
    required this.code,
    required this.key,
    this.location = 0,
    this.metaState = modifierNone,
    this.keyCode = 0,
  });

  final String code;

  final String key;

  final int location;

  final int metaState;

  final int keyCode;

  @override
  String get keyLabel => key == 'Unidentified' ? '' : _unicodeChar(key) ?? '';

  @override
  PhysicalKeyboardKey get physicalKey {
    return kWebToPhysicalKey[code] ?? PhysicalKeyboardKey(LogicalKeyboardKey.webPlane + code.hashCode);
  }

  @override
  LogicalKeyboardKey get logicalKey {
    // Look to see if the keyCode is a key based on location. Typically they are
    // numpad keys (versus main area keys) and left/right modifiers.
    final LogicalKeyboardKey? maybeLocationKey = kWebLocationMap[key]?[location];
    if (maybeLocationKey != null) {
      return maybeLocationKey;
    }

    // Look to see if the [key] is one we know about and have a mapping for.
    final LogicalKeyboardKey? newKey = kWebToLogicalKey[key];
    if (newKey != null) {
      return newKey;
    }

    final bool isPrintable = key.length == 1;
    if (isPrintable) {
      return LogicalKeyboardKey(key.toLowerCase().codeUnitAt(0));
    }

    // This is a non-printable key that we don't know about, so we mint a new
    // key from `code`. Don't mint with `key`, because the `key` will always be
    // "Unidentified" .
    return LogicalKeyboardKey(code.hashCode + LogicalKeyboardKey.webPlane);
  }

  @override
  bool isModifierPressed(
    ModifierKey key, {
    KeyboardSide side = KeyboardSide.any,
  }) {
    switch (key) {
      case ModifierKey.controlModifier:
        return metaState & modifierControl != 0;
      case ModifierKey.shiftModifier:
        return metaState & modifierShift != 0;
      case ModifierKey.altModifier:
        return metaState & modifierAlt != 0;
      case ModifierKey.metaModifier:
        return metaState & modifierMeta != 0;
      case ModifierKey.numLockModifier:
        return metaState & modifierNumLock != 0;
      case ModifierKey.capsLockModifier:
        return metaState & modifierCapsLock != 0;
      case ModifierKey.scrollLockModifier:
        return metaState & modifierScrollLock != 0;
      case ModifierKey.functionModifier:
      case ModifierKey.symbolModifier:
        // On Web, the browser doesn't report the state of the FN and SYM modifiers.
        return false;
    }
  }

  @override
  KeyboardSide getModifierSide(ModifierKey key) {
    // On Web, we don't distinguish the sides of modifier keys. Both left shift
    // and right shift, for example, are reported as the "Shift" modifier.
    //
    // See <https://developer.mozilla.org/en-US/docs/Web/API/KeyboardEvent/getModifierState>
    // for more information.
    return KeyboardSide.any;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
        properties.add(DiagnosticsProperty<String>('code', code));
        properties.add(DiagnosticsProperty<String>('key', key));
        properties.add(DiagnosticsProperty<int>('location', location));
        properties.add(DiagnosticsProperty<int>('metaState', metaState));
        properties.add(DiagnosticsProperty<int>('keyCode', keyCode));
  }

  @override
  bool operator==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is RawKeyEventDataWeb
        && other.code == code
        && other.key == key
        && other.location == location
        && other.metaState == metaState
        && other.keyCode == keyCode;
  }

  @override
  int get hashCode => Object.hash(
    code,
    key,
    location,
    metaState,
    keyCode,
  );

  // Modifier key masks.

  static const int modifierNone = 0;

  static const int modifierShift = 0x01;

  static const int modifierAlt = 0x02;

  static const int modifierControl = 0x04;

  static const int modifierMeta = 0x08;

  static const int modifierNumLock = 0x10;

  static const int modifierCapsLock = 0x20;

  static const int modifierScrollLock = 0x40;
}