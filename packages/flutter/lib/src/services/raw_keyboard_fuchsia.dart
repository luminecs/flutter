import 'package:flutter/foundation.dart';

import 'keyboard_maps.g.dart';
import 'raw_keyboard.dart';

export 'package:flutter/foundation.dart' show DiagnosticPropertiesBuilder;

export 'keyboard_key.g.dart' show LogicalKeyboardKey, PhysicalKeyboardKey;
export 'raw_keyboard.dart' show KeyboardSide, ModifierKey;

class RawKeyEventDataFuchsia extends RawKeyEventData {
  const RawKeyEventDataFuchsia({
    this.hidUsage = 0,
    this.codePoint = 0,
    this.modifiers = 0,
  });

  final int hidUsage;

  final int codePoint;

  final int modifiers;

  // Fuchsia only reports a single code point for the key label.
  @override
  String get keyLabel => codePoint == 0 ? '' : String.fromCharCode(codePoint);

  @override
  LogicalKeyboardKey get logicalKey {
    // If the key has a printable representation, then make a logical key based
    // on that.
    if (codePoint != 0) {
      final int flutterId = LogicalKeyboardKey.unicodePlane | codePoint & LogicalKeyboardKey.valueMask;
      return kFuchsiaToLogicalKey[flutterId] ?? LogicalKeyboardKey(LogicalKeyboardKey.unicodePlane | codePoint & LogicalKeyboardKey.valueMask);
    }

    // Look to see if the hidUsage is one we know about and have a mapping for.
    final LogicalKeyboardKey? newKey = kFuchsiaToLogicalKey[hidUsage | LogicalKeyboardKey.fuchsiaPlane];
    if (newKey != null) {
      return newKey;
    }

    // This is a non-printable key that we don't know about, so we mint a new
    // code.
    return LogicalKeyboardKey(hidUsage | LogicalKeyboardKey.fuchsiaPlane);
  }

  @override
  PhysicalKeyboardKey get physicalKey => kFuchsiaToPhysicalKey[hidUsage] ?? PhysicalKeyboardKey(LogicalKeyboardKey.fuchsiaPlane + hidUsage);

  bool _isLeftRightModifierPressed(KeyboardSide side, int anyMask, int leftMask, int rightMask) {
    if (modifiers & anyMask == 0) {
      return false;
    }
    switch (side) {
      case KeyboardSide.any:
        return true;
      case KeyboardSide.all:
        return modifiers & leftMask != 0 && modifiers & rightMask != 0;
      case KeyboardSide.left:
        return modifiers & leftMask != 0;
      case KeyboardSide.right:
        return modifiers & rightMask != 0;
    }
  }

  @override
  bool isModifierPressed(ModifierKey key, { KeyboardSide side = KeyboardSide.any }) {
    switch (key) {
      case ModifierKey.controlModifier:
        return _isLeftRightModifierPressed(side, modifierControl, modifierLeftControl, modifierRightControl);
      case ModifierKey.shiftModifier:
        return _isLeftRightModifierPressed(side, modifierShift, modifierLeftShift, modifierRightShift);
      case ModifierKey.altModifier:
        return _isLeftRightModifierPressed(side, modifierAlt, modifierLeftAlt, modifierRightAlt);
      case ModifierKey.metaModifier:
        return _isLeftRightModifierPressed(side, modifierMeta, modifierLeftMeta, modifierRightMeta);
      case ModifierKey.capsLockModifier:
        return modifiers & modifierCapsLock != 0;
      case ModifierKey.numLockModifier:
      case ModifierKey.scrollLockModifier:
      case ModifierKey.functionModifier:
      case ModifierKey.symbolModifier:
        // Fuchsia doesn't have masks for these keys (yet).
        return false;
    }
  }

  @override
  KeyboardSide? getModifierSide(ModifierKey key) {
    KeyboardSide? findSide(int anyMask, int leftMask, int rightMask) {
      final int combined = modifiers & anyMask;
      if (combined == leftMask) {
        return KeyboardSide.left;
      } else if (combined == rightMask) {
        return KeyboardSide.right;
      } else if (combined == anyMask) {
        return KeyboardSide.all;
      }
      return null;
    }

    switch (key) {
      case ModifierKey.controlModifier:
        return findSide(modifierControl, modifierLeftControl, modifierRightControl, );
      case ModifierKey.shiftModifier:
        return findSide(modifierShift, modifierLeftShift, modifierRightShift);
      case ModifierKey.altModifier:
        return findSide(modifierAlt, modifierLeftAlt, modifierRightAlt);
      case ModifierKey.metaModifier:
        return findSide(modifierMeta, modifierLeftMeta, modifierRightMeta);
      case ModifierKey.capsLockModifier:
        return (modifiers & modifierCapsLock == 0) ? null : KeyboardSide.all;
      case ModifierKey.numLockModifier:
      case ModifierKey.scrollLockModifier:
      case ModifierKey.functionModifier:
      case ModifierKey.symbolModifier:
        // Fuchsia doesn't support these modifiers, so they can't be pressed.
        return null;
    }
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<int>('hidUsage', hidUsage));
    properties.add(DiagnosticsProperty<int>('codePoint', codePoint));
    properties.add(DiagnosticsProperty<int>('modifiers', modifiers));
  }

  @override
  bool operator==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is RawKeyEventDataFuchsia
        && other.hidUsage == hidUsage
        && other.codePoint == codePoint
        && other.modifiers == modifiers;
  }

  @override
  int get hashCode => Object.hash(
    hidUsage,
    codePoint,
    modifiers,
  );

  // Keyboard modifier masks for Fuchsia modifiers.

  static const int modifierNone = 0x0;

  static const int modifierCapsLock = 0x1;

  static const int modifierLeftShift = 0x2;

  static const int modifierRightShift = 0x4;

  static const int modifierShift = modifierLeftShift | modifierRightShift;

  static const int modifierLeftControl = 0x8;

  static const int modifierRightControl = 0x10;

  static const int modifierControl = modifierLeftControl | modifierRightControl;

  static const int modifierLeftAlt = 0x20;

  static const int modifierRightAlt = 0x40;

  static const int modifierAlt = modifierLeftAlt | modifierRightAlt;

  static const int modifierLeftMeta = 0x80;

  static const int modifierRightMeta = 0x100;

  static const int modifierMeta = modifierLeftMeta | modifierRightMeta;
}