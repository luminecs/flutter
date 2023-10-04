import 'package:flutter/foundation.dart';

import 'keyboard_maps.g.dart';
import 'raw_keyboard.dart';

export 'package:flutter/foundation.dart' show DiagnosticPropertiesBuilder;

export 'keyboard_key.g.dart' show LogicalKeyboardKey, PhysicalKeyboardKey;
export 'raw_keyboard.dart' show KeyboardSide, ModifierKey;

int runeToLowerCase(int rune) {
  // Assume only Basic Multilingual Plane runes have lower and upper cases.
  // For other characters, return them as is.
  const int utf16BmpUpperBound = 0xD7FF;
  if (rune > utf16BmpUpperBound) {
    return rune;
  }
  return String.fromCharCode(rune).toLowerCase().codeUnitAt(0);
}

class RawKeyEventDataMacOs extends RawKeyEventData {
  const RawKeyEventDataMacOs({
    this.characters = '',
    this.charactersIgnoringModifiers = '',
    this.keyCode = 0,
    this.modifiers = 0,
    this.specifiedLogicalKey,
  });

  final String characters;

  final String charactersIgnoringModifiers;

  final int keyCode;

  final int modifiers;

  final int? specifiedLogicalKey;

  @override
  String get keyLabel => charactersIgnoringModifiers;

  @override
  PhysicalKeyboardKey get physicalKey =>
      kMacOsToPhysicalKey[keyCode] ??
      PhysicalKeyboardKey(LogicalKeyboardKey.windowsPlane + keyCode);

  @override
  LogicalKeyboardKey get logicalKey {
    if (specifiedLogicalKey != null) {
      final int key = specifiedLogicalKey!;
      return LogicalKeyboardKey.findKeyByKeyId(key) ?? LogicalKeyboardKey(key);
    }
    // Look to see if the keyCode is a printable number pad key, so that a
    // difference between regular keys (e.g. "=") and the number pad version
    // (e.g. the "=" on the number pad) can be determined.
    final LogicalKeyboardKey? numPadKey = kMacOsNumPadMap[keyCode];
    if (numPadKey != null) {
      return numPadKey;
    }

    // Keys that can't be derived with characterIgnoringModifiers will be
    // derived from their key codes using this map.
    final LogicalKeyboardKey? knownKey = kMacOsToLogicalKey[keyCode];
    if (knownKey != null) {
      return knownKey;
    }

    // If this key is a single printable character, generate the
    // LogicalKeyboardKey from its Unicode value. Control keys such as ESC,
    // CTRL, and SHIFT are not printable. HOME, DEL, arrow keys, and function
    // keys are considered modifier function keys, which generate invalid
    // Unicode scalar values. Multi-char characters are also discarded.
    int? character;
    if (keyLabel.isNotEmpty) {
      final List<int> codePoints = keyLabel.runes.toList();
      if (codePoints.length == 1 &&
          // Ideally we should test whether `codePoints[0]` is in the range.
          // Since LogicalKeyboardKey.isControlCharacter and _isUnprintableKey
          // only tests BMP, it is fine to test keyLabel instead.
          !LogicalKeyboardKey.isControlCharacter(keyLabel) &&
          !_isUnprintableKey(keyLabel)) {
        character = runeToLowerCase(codePoints[0]);
      }
    }
    if (character != null) {
      final int keyId = LogicalKeyboardKey.unicodePlane |
          (character & LogicalKeyboardKey.valueMask);
      return LogicalKeyboardKey.findKeyByKeyId(keyId) ??
          LogicalKeyboardKey(keyId);
    }

    // This is a non-printable key that we don't know about, so we mint a new
    // code.
    return LogicalKeyboardKey(keyCode | LogicalKeyboardKey.macosPlane);
  }

  bool _isLeftRightModifierPressed(
      KeyboardSide side, int anyMask, int leftMask, int rightMask) {
    if (modifiers & anyMask == 0) {
      return false;
    }
    // If only the "anyMask" bit is set, then we respond true for requests of
    // whether either left or right is pressed. Handles the case where macOS
    // supplies just the "either" modifier flag, but not the left/right flag.
    // (e.g. modifierShift but not modifierLeftShift).
    final bool anyOnly =
        modifiers & (leftMask | rightMask | anyMask) == anyMask;
    switch (side) {
      case KeyboardSide.any:
        return true;
      case KeyboardSide.all:
        return modifiers & leftMask != 0 && modifiers & rightMask != 0 ||
            anyOnly;
      case KeyboardSide.left:
        return modifiers & leftMask != 0 || anyOnly;
      case KeyboardSide.right:
        return modifiers & rightMask != 0 || anyOnly;
    }
  }

  @override
  bool isModifierPressed(ModifierKey key,
      {KeyboardSide side = KeyboardSide.any}) {
    final int independentModifier = modifiers & deviceIndependentMask;
    final bool result;
    switch (key) {
      case ModifierKey.controlModifier:
        result = _isLeftRightModifierPressed(
            side,
            independentModifier & modifierControl,
            modifierLeftControl,
            modifierRightControl);
      case ModifierKey.shiftModifier:
        result = _isLeftRightModifierPressed(
            side,
            independentModifier & modifierShift,
            modifierLeftShift,
            modifierRightShift);
      case ModifierKey.altModifier:
        result = _isLeftRightModifierPressed(
            side,
            independentModifier & modifierOption,
            modifierLeftOption,
            modifierRightOption);
      case ModifierKey.metaModifier:
        result = _isLeftRightModifierPressed(
            side,
            independentModifier & modifierCommand,
            modifierLeftCommand,
            modifierRightCommand);
      case ModifierKey.capsLockModifier:
        result = independentModifier & modifierCapsLock != 0;
      // On macOS, the function modifier bit is set for any function key, like F1,
      // F2, etc., but the meaning of ModifierKey.modifierFunction in Flutter is
      // that of the Fn modifier key, so there's no good way to emulate that on
      // macOS.
      case ModifierKey.functionModifier:
      case ModifierKey.numLockModifier:
      case ModifierKey.symbolModifier:
      case ModifierKey.scrollLockModifier:
        // These modifier masks are not used in macOS keyboards.
        result = false;
    }
    assert(!result || getModifierSide(key) != null,
        "$runtimeType thinks that a modifier is pressed, but can't figure out what side it's on.");
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
      } else if (combined == combinedMask ||
          modifiers & (combinedMask | anyMask) == anyMask) {
        // Handles the case where macOS supplies just the "either" modifier
        // flag, but not the left/right flag. (e.g. modifierShift but not
        // modifierLeftShift), or if left and right flags are provided, but not
        // the "either" modifier flag.
        return KeyboardSide.all;
      }
      return null;
    }

    switch (key) {
      case ModifierKey.controlModifier:
        return findSide(
            modifierControl, modifierLeftControl, modifierRightControl);
      case ModifierKey.shiftModifier:
        return findSide(modifierShift, modifierLeftShift, modifierRightShift);
      case ModifierKey.altModifier:
        return findSide(
            modifierOption, modifierLeftOption, modifierRightOption);
      case ModifierKey.metaModifier:
        return findSide(
            modifierCommand, modifierLeftCommand, modifierRightCommand);
      case ModifierKey.capsLockModifier:
      case ModifierKey.numLockModifier:
      case ModifierKey.scrollLockModifier:
      case ModifierKey.functionModifier:
      case ModifierKey.symbolModifier:
        return KeyboardSide.all;
    }
  }

  @override
  bool shouldDispatchEvent() {
    // On macOS laptop keyboards, the fn key is used to generate home/end and
    // f1-f12, but it ALSO generates a separate down/up event for the fn key
    // itself. Other platforms hide the fn key, and just produce the key that
    // it is combined with, so to keep it possible to write cross platform
    // code that looks at which keys are pressed, the fn key is ignored on
    // macOS.
    return logicalKey != LogicalKeyboardKey.fn;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<String>('characters', characters));
    properties.add(DiagnosticsProperty<String>(
        'charactersIgnoringModifiers', charactersIgnoringModifiers));
    properties.add(DiagnosticsProperty<int>('keyCode', keyCode));
    properties.add(DiagnosticsProperty<int>('modifiers', modifiers));
    properties.add(DiagnosticsProperty<int?>(
        'specifiedLogicalKey', specifiedLogicalKey,
        defaultValue: null));
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is RawKeyEventDataMacOs &&
        other.characters == characters &&
        other.charactersIgnoringModifiers == charactersIgnoringModifiers &&
        other.keyCode == keyCode &&
        other.modifiers == modifiers;
  }

  @override
  int get hashCode => Object.hash(
        characters,
        charactersIgnoringModifiers,
        keyCode,
        modifiers,
      );

  static bool _isUnprintableKey(String label) {
    if (label.length != 1) {
      return false;
    }
    final int codeUnit = label.codeUnitAt(0);
    return codeUnit >= 0xF700 && codeUnit <= 0xF8FF;
  }

  // Modifier key masks. See Apple's NSEvent documentation
  // https://developer.apple.com/documentation/appkit/nseventmodifierflags?language=objc
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
