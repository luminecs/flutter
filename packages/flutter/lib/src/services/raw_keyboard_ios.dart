
import 'package:flutter/foundation.dart';

import 'keyboard_maps.g.dart';
import 'raw_keyboard.dart';

export 'package:flutter/foundation.dart' show DiagnosticPropertiesBuilder;

export 'keyboard_key.g.dart' show LogicalKeyboardKey, PhysicalKeyboardKey;
export 'raw_keyboard.dart' show KeyboardSide, ModifierKey;

class RawKeyEventDataIos extends RawKeyEventData {
  const RawKeyEventDataIos({
    this.characters = '',
    this.charactersIgnoringModifiers = '',
    this.keyCode = 0,
    this.modifiers = 0,
  });

  final String characters;

  final String charactersIgnoringModifiers;

  final int keyCode;

  final int modifiers;

  @override
  String get keyLabel => charactersIgnoringModifiers;

  @override
  PhysicalKeyboardKey get physicalKey => kIosToPhysicalKey[keyCode] ?? PhysicalKeyboardKey(LogicalKeyboardKey.iosPlane + keyCode);

  @override
  LogicalKeyboardKey get logicalKey {
    // Look to see if the keyCode is a printable number pad key, so that a
    // difference between regular keys (e.g. "=") and the number pad version
    // (e.g. the "=" on the number pad) can be determined.
    final LogicalKeyboardKey? numPadKey = kIosNumPadMap[keyCode];
    if (numPadKey != null) {
      return numPadKey;
    }

    // Look to see if the [keyLabel] is one we know about and have a mapping for.
    final LogicalKeyboardKey? specialKey = kIosSpecialLogicalMap[keyLabel];
    if (specialKey != null) {
      return specialKey;
    }

    // Keys that can't be derived with characterIgnoringModifiers will be
    // derived from their key codes using this map.
    final LogicalKeyboardKey? knownKey = kIosToLogicalKey[keyCode];
    if (knownKey != null) {
      return knownKey;
    }

    // If this key is printable, generate the LogicalKeyboardKey from its
    // Unicode value. Control keys such as ESC, CTRL, and SHIFT are not
    // printable. HOME, DEL, arrow keys, and function keys are considered
    // modifier function keys, which generate invalid Unicode scalar values.
    if (keyLabel.isNotEmpty &&
        !LogicalKeyboardKey.isControlCharacter(keyLabel) &&
        !_isUnprintableKey(keyLabel)) {
      // Given that charactersIgnoringModifiers can contain a String of
      // arbitrary length, limit to a maximum of two Unicode scalar values. It
      // is unlikely that a keyboard would produce a code point bigger than 32
      // bits, but it is still worth defending against this case.
      assert(charactersIgnoringModifiers.length <= 2);
      int codeUnit = charactersIgnoringModifiers.codeUnitAt(0);
      if (charactersIgnoringModifiers.length == 2) {
        final int secondCode = charactersIgnoringModifiers.codeUnitAt(1);
        codeUnit = (codeUnit << 16) | secondCode;
      }

      final int keyId = LogicalKeyboardKey.unicodePlane | (codeUnit & LogicalKeyboardKey.valueMask);
      return LogicalKeyboardKey.findKeyByKeyId(keyId) ?? LogicalKeyboardKey(keyId);
    }

    // This is a non-printable key that we don't know about, so we mint a new
    // code.
    return LogicalKeyboardKey(keyCode | LogicalKeyboardKey.iosPlane);
  }

  static bool _isUnprintableKey(String label) {
    if (label.length != 1) {
      return false;
    }
    final int codeUnit = label.codeUnitAt(0);
    return codeUnit >= 0xF700 && codeUnit <= 0xF8FF;
  }

  bool _isLeftRightModifierPressed(KeyboardSide side, int anyMask, int leftMask, int rightMask) {
    if (modifiers & anyMask == 0) {
      return false;
    }
    // If only the "anyMask" bit is set, then we respond true for requests of
    // whether either left or right is pressed. Handles the case where iOS
    // supplies just the "either" modifier flag, but not the left/right flag.
    // (e.g. modifierShift but not modifierLeftShift).
    final bool anyOnly = modifiers & (leftMask | rightMask | anyMask) == anyMask;
    switch (side) {
      case KeyboardSide.any:
        return true;
      case KeyboardSide.all:
        return modifiers & leftMask != 0 && modifiers & rightMask != 0 || anyOnly;
      case KeyboardSide.left:
        return modifiers & leftMask != 0 || anyOnly;
      case KeyboardSide.right:
        return modifiers & rightMask != 0 || anyOnly;
    }
  }

  @override
  bool isModifierPressed(ModifierKey key, {KeyboardSide side = KeyboardSide.any}) {
    final int independentModifier = modifiers & deviceIndependentMask;
    bool result;
    switch (key) {
      case ModifierKey.controlModifier:
        result = _isLeftRightModifierPressed(side, independentModifier & modifierControl, modifierLeftControl, modifierRightControl);
      case ModifierKey.shiftModifier:
        result = _isLeftRightModifierPressed(side, independentModifier & modifierShift, modifierLeftShift, modifierRightShift);
      case ModifierKey.altModifier:
        result = _isLeftRightModifierPressed(side, independentModifier & modifierOption, modifierLeftOption, modifierRightOption);
      case ModifierKey.metaModifier:
        result = _isLeftRightModifierPressed(side, independentModifier & modifierCommand, modifierLeftCommand, modifierRightCommand);
      case ModifierKey.capsLockModifier:
        result = independentModifier & modifierCapsLock != 0;
    // On iOS, the function modifier bit is set for any function key, like F1,
    // F2, etc., but the meaning of ModifierKey.modifierFunction in Flutter is
    // that of the Fn modifier key, so there's no good way to emulate that on
    // iOS.
      case ModifierKey.functionModifier:
      case ModifierKey.numLockModifier:
      case ModifierKey.symbolModifier:
      case ModifierKey.scrollLockModifier:
        // These modifier masks are not used in iOS keyboards.
        result = false;
    }
    assert(!result || getModifierSide(key) != null, "$runtimeType thinks that a modifier is pressed, but can't figure out what side it's on.");
    return result;
  }

  @override
  KeyboardSide? getModifierSide(ModifierKey key) {
    KeyboardSide? findSide(int anyMask, int leftMask, int rightMask) {
      final int combinedMask = leftMask | rightMask;
      final int combined = modifiers & combinedMask;
      if (combined == leftMask) {
        return KeyboardSide.left;
      } else if (combined == rightMask) {
        return KeyboardSide.right;
      } else if (combined == combinedMask || modifiers & (combinedMask | anyMask) == anyMask) {
        // Handles the case where iOS supplies just the "either" modifier
        // flag, but not the left/right flag. (e.g. modifierShift but not
        // modifierLeftShift), or if left and right flags are provided, but not
        // the "either" modifier flag.
        return KeyboardSide.all;
      }
      return null;
    }

    switch (key) {
      case ModifierKey.controlModifier:
        return findSide(modifierControl, modifierLeftControl, modifierRightControl);
      case ModifierKey.shiftModifier:
        return findSide(modifierShift, modifierLeftShift, modifierRightShift);
      case ModifierKey.altModifier:
        return findSide(modifierOption, modifierLeftOption, modifierRightOption);
      case ModifierKey.metaModifier:
        return findSide(modifierCommand, modifierLeftCommand, modifierRightCommand);
      case ModifierKey.capsLockModifier:
      case ModifierKey.numLockModifier:
      case ModifierKey.scrollLockModifier:
      case ModifierKey.functionModifier:
      case ModifierKey.symbolModifier:
        return KeyboardSide.all;
    }
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
        properties.add(DiagnosticsProperty<String>('characters', characters));
        properties.add(DiagnosticsProperty<String>('charactersIgnoringModifiers', charactersIgnoringModifiers));
        properties.add(DiagnosticsProperty<int>('keyCode', keyCode));
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
    return other is RawKeyEventDataIos
        && other.characters == characters
        && other.charactersIgnoringModifiers == charactersIgnoringModifiers
        && other.keyCode == keyCode
        && other.modifiers == modifiers;
  }

  @override
  int get hashCode => Object.hash(
    characters,
    charactersIgnoringModifiers,
    keyCode,
    modifiers,
  );

  // Modifier key masks. See Apple's UIKey documentation
  // https://developer.apple.com/documentation/uikit/uikeymodifierflags?language=objc
  // https://opensource.apple.com/source/IOHIDFamily/IOHIDFamily-86/IOHIDSystem/IOKit/hidsystem/IOLLEvent.h.auto.html

  static const int modifierCapsLock = 0x10000;

  static const int modifierShift = 0x20000;

  static const int modifierLeftShift = 0x02;

  static const int modifierRightShift = 0x04;

  static const int modifierControl = 0x40000;

  static const int modifierLeftControl = 0x01;

  static const int modifierRightControl = 0x2000;

  static const int modifierOption = 0x80000;

  static const int modifierLeftOption = 0x20;

  static const int modifierRightOption = 0x40;

  static const int modifierCommand = 0x100000;

  static const int modifierLeftCommand = 0x08;

  static const int modifierRightCommand = 0x10;

  static const int modifierNumericPad = 0x200000;

  static const int modifierHelp = 0x400000;

  static const int modifierFunction = 0x800000;

  static const int deviceIndependentMask = 0xffff0000;
}