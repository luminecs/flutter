
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'binding.dart';
import 'hardware_keyboard.dart';
import 'keyboard_key.g.dart';
import 'raw_keyboard_android.dart';
import 'raw_keyboard_fuchsia.dart';
import 'raw_keyboard_ios.dart';
import 'raw_keyboard_linux.dart';
import 'raw_keyboard_macos.dart';
import 'raw_keyboard_web.dart';
import 'raw_keyboard_windows.dart';
import 'system_channels.dart';

export 'package:flutter/foundation.dart' show DiagnosticPropertiesBuilder, ValueChanged;

export 'keyboard_key.g.dart' show LogicalKeyboardKey, PhysicalKeyboardKey;

enum KeyboardSide {
  any,

  left,

  right,

  all,
}

enum ModifierKey {
  controlModifier,

  shiftModifier,

  altModifier,

  metaModifier,

  capsLockModifier,

  numLockModifier,

  scrollLockModifier,

  functionModifier,

  symbolModifier,
}

@immutable
abstract class RawKeyEventData with Diagnosticable {
  const RawKeyEventData();

  bool isModifierPressed(ModifierKey key, { KeyboardSide side = KeyboardSide.any });

  KeyboardSide? getModifierSide(ModifierKey key);

  bool get isControlPressed => isModifierPressed(ModifierKey.controlModifier);

  bool get isShiftPressed => isModifierPressed(ModifierKey.shiftModifier);

  bool get isAltPressed => isModifierPressed(ModifierKey.altModifier);

  bool get isMetaPressed => isModifierPressed(ModifierKey.metaModifier);

  Map<ModifierKey, KeyboardSide> get modifiersPressed {
    final Map<ModifierKey, KeyboardSide> result = <ModifierKey, KeyboardSide>{};
    for (final ModifierKey key in ModifierKey.values) {
      if (isModifierPressed(key)) {
        final KeyboardSide? side = getModifierSide(key);
        if (side != null) {
          result[key] = side;
        }
        assert(() {
          if (side == null) {
            debugPrint(
              'Raw key data is returning inconsistent information for '
              'pressed modifiers. isModifierPressed returns true for $key '
              'being pressed, but when getModifierSide is called, it says '
              'that no modifiers are pressed.',
            );
            if (this is RawKeyEventDataAndroid) {
              debugPrint('Android raw key metaState: ${(this as RawKeyEventDataAndroid).metaState}');
            }
          }
          return true;
        }());
      }
    }
    return result;
  }

  PhysicalKeyboardKey get physicalKey;

  LogicalKeyboardKey get logicalKey;

  String get keyLabel;

  bool shouldDispatchEvent() {
    return true;
  }
}

@immutable
abstract class RawKeyEvent with Diagnosticable {
  const RawKeyEvent({
    required this.data,
    this.character,
    this.repeat = false,
  });

  factory RawKeyEvent.fromMessage(Map<String, Object?> message) {
    String? character;
    RawKeyEventData dataFromWeb() {
      final String? key = message['key'] as String?;
      if (key != null && key.isNotEmpty && key.length == 1) {
        character = key;
      }
      return RawKeyEventDataWeb(
        code: message['code'] as String? ?? '',
        key: key ?? '',
        location: message['location'] as int? ?? 0,
        metaState: message['metaState'] as int? ?? 0,
        keyCode: message['keyCode'] as int? ?? 0,
      );
    }

    final RawKeyEventData data;
    if (kIsWeb) {
      data = dataFromWeb();
    } else {
      final String keymap = message['keymap']! as String;
      switch (keymap) {
        case 'android':
          data = RawKeyEventDataAndroid(
            flags: message['flags'] as int? ?? 0,
            codePoint: message['codePoint'] as int? ?? 0,
            keyCode: message['keyCode'] as int? ?? 0,
            plainCodePoint: message['plainCodePoint'] as int? ?? 0,
            scanCode: message['scanCode'] as int? ?? 0,
            metaState: message['metaState'] as int? ?? 0,
            eventSource: message['source'] as int? ?? 0,
            vendorId: message['vendorId'] as int? ?? 0,
            productId: message['productId'] as int? ?? 0,
            deviceId: message['deviceId'] as int? ?? 0,
            repeatCount: message['repeatCount'] as int? ?? 0,
          );
          if (message.containsKey('character')) {
            character = message['character'] as String?;
          }
        case 'fuchsia':
          final int codePoint = message['codePoint'] as int? ?? 0;
          data = RawKeyEventDataFuchsia(
            hidUsage: message['hidUsage'] as int? ?? 0,
            codePoint: codePoint,
            modifiers: message['modifiers'] as int? ?? 0,
          );
          if (codePoint != 0) {
            character = String.fromCharCode(codePoint);
          }
        case 'macos':
          data = RawKeyEventDataMacOs(
            characters: message['characters'] as String? ?? '',
            charactersIgnoringModifiers: message['charactersIgnoringModifiers'] as String? ?? '',
            keyCode: message['keyCode'] as int? ?? 0,
            modifiers: message['modifiers'] as int? ?? 0,
            specifiedLogicalKey: message['specifiedLogicalKey'] as int?,
          );
          character = message['characters'] as String?;
        case 'ios':
          data = RawKeyEventDataIos(
            characters: message['characters'] as String? ?? '',
            charactersIgnoringModifiers: message['charactersIgnoringModifiers'] as String? ?? '',
            keyCode: message['keyCode'] as int? ?? 0,
            modifiers: message['modifiers'] as int? ?? 0,
          );
        case 'linux':
          final int unicodeScalarValues = message['unicodeScalarValues'] as int? ?? 0;
          data = RawKeyEventDataLinux(
            keyHelper: KeyHelper(message['toolkit'] as String? ?? ''),
            unicodeScalarValues: unicodeScalarValues,
            keyCode: message['keyCode'] as int? ?? 0,
            scanCode: message['scanCode'] as int? ?? 0,
            modifiers: message['modifiers'] as int? ?? 0,
            isDown: message['type'] == 'keydown',
            specifiedLogicalKey: message['specifiedLogicalKey'] as int?,
          );
          if (unicodeScalarValues != 0) {
            character = String.fromCharCode(unicodeScalarValues);
          }
        case 'windows':
          final int characterCodePoint = message['characterCodePoint'] as int? ?? 0;
          data = RawKeyEventDataWindows(
            keyCode: message['keyCode'] as int? ?? 0,
            scanCode: message['scanCode'] as int? ?? 0,
            characterCodePoint: characterCodePoint,
            modifiers: message['modifiers'] as int? ?? 0,
          );
          if (characterCodePoint != 0) {
            character = String.fromCharCode(characterCodePoint);
          }
        case 'web':
          data = dataFromWeb();
        default:
          throw FlutterError('Unknown keymap for key events: $keymap');
      }
    }
    final bool repeat = RawKeyboard.instance.physicalKeysPressed.contains(data.physicalKey);
    final String type = message['type']! as String;
    switch (type) {
      case 'keydown':
        return RawKeyDownEvent(data: data, character: character, repeat: repeat);
      case 'keyup':
        return RawKeyUpEvent(data: data);
      default:
        throw FlutterError('Unknown key event type: $type');
    }
  }

  bool isKeyPressed(LogicalKeyboardKey key) => RawKeyboard.instance.keysPressed.contains(key);

  bool get isControlPressed {
    return isKeyPressed(LogicalKeyboardKey.controlLeft) || isKeyPressed(LogicalKeyboardKey.controlRight);
  }

  bool get isShiftPressed {
    return isKeyPressed(LogicalKeyboardKey.shiftLeft) || isKeyPressed(LogicalKeyboardKey.shiftRight);
  }

  bool get isAltPressed {
    return isKeyPressed(LogicalKeyboardKey.altLeft) || isKeyPressed(LogicalKeyboardKey.altRight);
  }

  bool get isMetaPressed {
    return isKeyPressed(LogicalKeyboardKey.metaLeft) || isKeyPressed(LogicalKeyboardKey.metaRight);
  }

  PhysicalKeyboardKey get physicalKey => data.physicalKey;

  LogicalKeyboardKey get logicalKey => data.logicalKey;

  final String? character;

  final bool repeat;

  final RawKeyEventData data;

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<LogicalKeyboardKey>('logicalKey', logicalKey));
    properties.add(DiagnosticsProperty<PhysicalKeyboardKey>('physicalKey', physicalKey));
    if (this is RawKeyDownEvent) {
      properties.add(DiagnosticsProperty<bool>('repeat', repeat));
    }
  }
}

class RawKeyDownEvent extends RawKeyEvent {
  const RawKeyDownEvent({
    required super.data,
    super.character,
    super.repeat,
  });
}

class RawKeyUpEvent extends RawKeyEvent {
  const RawKeyUpEvent({
    required super.data,
    super.character,
  }) : super(repeat: false);
}

typedef RawKeyEventHandler = bool Function(RawKeyEvent event);

class RawKeyboard {
  RawKeyboard._();

  static final RawKeyboard instance = RawKeyboard._();

  final List<ValueChanged<RawKeyEvent>> _listeners = <ValueChanged<RawKeyEvent>>[];

  void addListener(ValueChanged<RawKeyEvent> listener) {
    _listeners.add(listener);
  }

  void removeListener(ValueChanged<RawKeyEvent> listener) {
    _listeners.remove(listener);
  }

  RawKeyEventHandler? get keyEventHandler {
    if (ServicesBinding.instance.keyEventManager.keyMessageHandler != _cachedKeyMessageHandler) {
      _cachedKeyMessageHandler = ServicesBinding.instance.keyEventManager.keyMessageHandler;
      _cachedKeyEventHandler = _cachedKeyMessageHandler == null ?
        null :
        (RawKeyEvent event) {
          assert(false,
              'The RawKeyboard.instance.keyEventHandler assigned by Flutter is a dummy '
              'callback kept for compatibility and should not be directly called. Use '
              'ServicesBinding.instance!.keyMessageHandler instead.');
          return true;
        };
    }
    return _cachedKeyEventHandler;
  }
  RawKeyEventHandler? _cachedKeyEventHandler;
  KeyMessageHandler? _cachedKeyMessageHandler;
  set keyEventHandler(RawKeyEventHandler? handler) {
    _cachedKeyEventHandler = handler;
    _cachedKeyMessageHandler = handler == null ?
      null :
      (KeyMessage message) {
        if (message.rawEvent != null) {
          return handler(message.rawEvent!);
        }
        return false;
      };
    ServicesBinding.instance.keyEventManager.keyMessageHandler = _cachedKeyMessageHandler;
  }

  bool handleRawKeyEvent(RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      _keysPressed[event.physicalKey] = event.logicalKey;
    } else if (event is RawKeyUpEvent) {
      // Use the physical key in the key up event to find the physical key from
      // the corresponding key down event and remove it, even if the logical
      // keys don't match.
      _keysPressed.remove(event.physicalKey);
    }
    // Make sure that the modifiers reflect reality, in case a modifier key was
    // pressed/released while the app didn't have focus.
    _synchronizeModifiers(event);
    assert(
      event is! RawKeyDownEvent || _keysPressed.isNotEmpty,
      'Attempted to send a key down event when no keys are in keysPressed. '
      "This state can occur if the key event being sent doesn't properly "
      'set its modifier flags. This was the event: $event and its data: '
      '${event.data}',
    );
    // Send the event to passive listeners.
    for (final ValueChanged<RawKeyEvent> listener in List<ValueChanged<RawKeyEvent>>.of(_listeners)) {
      try {
        if (_listeners.contains(listener)) {
          listener(event);
        }
      } catch (exception, stack) {
        InformationCollector? collector;
        assert(() {
          collector = () => <DiagnosticsNode>[
            DiagnosticsProperty<RawKeyEvent>('Event', event),
          ];
          return true;
        }());
        FlutterError.reportError(FlutterErrorDetails(
          exception: exception,
          stack: stack,
          library: 'services library',
          context: ErrorDescription('while processing a raw key listener'),
          informationCollector: collector,
        ));
      }
    }

    return false;
  }

  static final Map<_ModifierSidePair, Set<PhysicalKeyboardKey>> _modifierKeyMap = <_ModifierSidePair, Set<PhysicalKeyboardKey>>{
    const _ModifierSidePair(ModifierKey.altModifier, KeyboardSide.left): <PhysicalKeyboardKey>{PhysicalKeyboardKey.altLeft},
    const _ModifierSidePair(ModifierKey.altModifier, KeyboardSide.right): <PhysicalKeyboardKey>{PhysicalKeyboardKey.altRight},
    const _ModifierSidePair(ModifierKey.altModifier, KeyboardSide.all): <PhysicalKeyboardKey>{PhysicalKeyboardKey.altLeft, PhysicalKeyboardKey.altRight},
    const _ModifierSidePair(ModifierKey.altModifier, KeyboardSide.any): <PhysicalKeyboardKey>{PhysicalKeyboardKey.altLeft},
    const _ModifierSidePair(ModifierKey.shiftModifier, KeyboardSide.left): <PhysicalKeyboardKey>{PhysicalKeyboardKey.shiftLeft},
    const _ModifierSidePair(ModifierKey.shiftModifier, KeyboardSide.right): <PhysicalKeyboardKey>{PhysicalKeyboardKey.shiftRight},
    const _ModifierSidePair(ModifierKey.shiftModifier, KeyboardSide.all): <PhysicalKeyboardKey>{PhysicalKeyboardKey.shiftLeft, PhysicalKeyboardKey.shiftRight},
    const _ModifierSidePair(ModifierKey.shiftModifier, KeyboardSide.any): <PhysicalKeyboardKey>{PhysicalKeyboardKey.shiftLeft},
    const _ModifierSidePair(ModifierKey.controlModifier, KeyboardSide.left): <PhysicalKeyboardKey>{PhysicalKeyboardKey.controlLeft},
    const _ModifierSidePair(ModifierKey.controlModifier, KeyboardSide.right): <PhysicalKeyboardKey>{PhysicalKeyboardKey.controlRight},
    const _ModifierSidePair(ModifierKey.controlModifier, KeyboardSide.all): <PhysicalKeyboardKey>{PhysicalKeyboardKey.controlLeft, PhysicalKeyboardKey.controlRight},
    const _ModifierSidePair(ModifierKey.controlModifier, KeyboardSide.any): <PhysicalKeyboardKey>{PhysicalKeyboardKey.controlLeft},
    const _ModifierSidePair(ModifierKey.metaModifier, KeyboardSide.left): <PhysicalKeyboardKey>{PhysicalKeyboardKey.metaLeft},
    const _ModifierSidePair(ModifierKey.metaModifier, KeyboardSide.right): <PhysicalKeyboardKey>{PhysicalKeyboardKey.metaRight},
    const _ModifierSidePair(ModifierKey.metaModifier, KeyboardSide.all): <PhysicalKeyboardKey>{PhysicalKeyboardKey.metaLeft, PhysicalKeyboardKey.metaRight},
    const _ModifierSidePair(ModifierKey.metaModifier, KeyboardSide.any): <PhysicalKeyboardKey>{PhysicalKeyboardKey.metaLeft},
    const _ModifierSidePair(ModifierKey.capsLockModifier, KeyboardSide.all): <PhysicalKeyboardKey>{PhysicalKeyboardKey.capsLock},
    const _ModifierSidePair(ModifierKey.numLockModifier, KeyboardSide.all): <PhysicalKeyboardKey>{PhysicalKeyboardKey.numLock},
    const _ModifierSidePair(ModifierKey.scrollLockModifier, KeyboardSide.all): <PhysicalKeyboardKey>{PhysicalKeyboardKey.scrollLock},
    const _ModifierSidePair(ModifierKey.functionModifier, KeyboardSide.all): <PhysicalKeyboardKey>{PhysicalKeyboardKey.fn},
    // The symbolModifier doesn't have a key representation on any of the
    // platforms, so don't map it here.
  };

  // The map of all modifier keys except Fn, since that is treated differently
  // on some platforms.
  static final Map<PhysicalKeyboardKey, LogicalKeyboardKey> _allModifiersExceptFn = <PhysicalKeyboardKey, LogicalKeyboardKey>{
    PhysicalKeyboardKey.altLeft: LogicalKeyboardKey.altLeft,
    PhysicalKeyboardKey.altRight: LogicalKeyboardKey.altRight,
    PhysicalKeyboardKey.shiftLeft: LogicalKeyboardKey.shiftLeft,
    PhysicalKeyboardKey.shiftRight: LogicalKeyboardKey.shiftRight,
    PhysicalKeyboardKey.controlLeft: LogicalKeyboardKey.controlLeft,
    PhysicalKeyboardKey.controlRight: LogicalKeyboardKey.controlRight,
    PhysicalKeyboardKey.metaLeft: LogicalKeyboardKey.metaLeft,
    PhysicalKeyboardKey.metaRight: LogicalKeyboardKey.metaRight,
    PhysicalKeyboardKey.capsLock: LogicalKeyboardKey.capsLock,
    PhysicalKeyboardKey.numLock: LogicalKeyboardKey.numLock,
    PhysicalKeyboardKey.scrollLock: LogicalKeyboardKey.scrollLock,
  };

  // The map of all modifier keys that are represented in modifier key bit
  // masks on all platforms, so that they can be cleared out of pressedKeys when
  // synchronizing.
  static final Map<PhysicalKeyboardKey, LogicalKeyboardKey> _allModifiers = <PhysicalKeyboardKey, LogicalKeyboardKey>{
    PhysicalKeyboardKey.fn: LogicalKeyboardKey.fn,
    ..._allModifiersExceptFn,
  };

  void _synchronizeModifiers(RawKeyEvent event) {
    // Compare modifier states to the ground truth as specified by
    // [RawKeyEvent.data.modifiersPressed] and update unsynchronized ones.
    //
    // This function will update the state of modifier keys in `_keysPressed` so
    // that they match the ones given by [RawKeyEvent.data.modifiersPressed].
    // For a `modifiersPressed` result of anything but [KeyboardSide.any], the
    // states in `_keysPressed` will be updated to exactly match the result,
    // i.e. exactly one of "no down", "left down", "right down" or "both down".
    //
    // If `modifiersPressed` returns [KeyboardSide.any], the states in
    // `_keysPressed` will be updated to a rough match, i.e. "either side down"
    // or "no down". If `_keysPressed` has no modifier down, a
    // [KeyboardSide.any] will synchronize by forcing the left modifier down. If
    // `_keysPressed` has any modifier down, a [KeyboardSide.any] will not cause
    // a state change.

    final Map<ModifierKey, KeyboardSide?> modifiersPressed = event.data.modifiersPressed;
    final Map<PhysicalKeyboardKey, LogicalKeyboardKey> modifierKeys = <PhysicalKeyboardKey, LogicalKeyboardKey>{};
    // Physical keys that whose modifiers are pressed at any side.
    final Set<PhysicalKeyboardKey> anySideKeys = <PhysicalKeyboardKey>{};
    final Set<PhysicalKeyboardKey> keysPressedAfterEvent = <PhysicalKeyboardKey>{
      ..._keysPressed.keys,
      if (event is RawKeyDownEvent) event.physicalKey,
    };
    ModifierKey? thisKeyModifier;
    for (final ModifierKey key in ModifierKey.values) {
      final Set<PhysicalKeyboardKey>? thisModifierKeys = _modifierKeyMap[_ModifierSidePair(key, KeyboardSide.all)];
      if (thisModifierKeys == null) {
        continue;
      }
      if (thisModifierKeys.contains(event.physicalKey)) {
        thisKeyModifier = key;
      }
      if (modifiersPressed[key] == KeyboardSide.any) {
        anySideKeys.addAll(thisModifierKeys);
        if (thisModifierKeys.any(keysPressedAfterEvent.contains)) {
          continue;
        }
      }
      final Set<PhysicalKeyboardKey>? mappedKeys = modifiersPressed[key] == null ?
        <PhysicalKeyboardKey>{} : _modifierKeyMap[_ModifierSidePair(key, modifiersPressed[key])];
      assert(() {
        if (mappedKeys == null) {
          debugPrint(
            'Platform key support for ${Platform.operatingSystem} is '
            'producing unsupported modifier combinations for '
            'modifier $key on side ${modifiersPressed[key]}.',
          );
          if (event.data is RawKeyEventDataAndroid) {
            debugPrint('Android raw key metaState: ${(event.data as RawKeyEventDataAndroid).metaState}');
          }
        }
        return true;
      }());
      if (mappedKeys == null) {
        continue;
      }
      for (final PhysicalKeyboardKey physicalModifier in mappedKeys) {
        modifierKeys[physicalModifier] = _allModifiers[physicalModifier]!;
      }
    }
    // On Linux, CapsLock key can be mapped to a non-modifier logical key:
    // https://github.com/flutter/flutter/issues/114591.
    // This is also affecting Flutter Web on Linux.
    final bool nonModifierCapsLock = (event.data is RawKeyEventDataLinux  || event.data is RawKeyEventDataWeb)
      && _keysPressed[PhysicalKeyboardKey.capsLock] != null
      && _keysPressed[PhysicalKeyboardKey.capsLock] != LogicalKeyboardKey.capsLock;
    for (final PhysicalKeyboardKey physicalKey in _allModifiersExceptFn.keys) {
      final bool skipReleasingKey = nonModifierCapsLock && physicalKey == PhysicalKeyboardKey.capsLock;
      if (!anySideKeys.contains(physicalKey) && !skipReleasingKey) {
        _keysPressed.remove(physicalKey);
      }
    }
    if (event.data is! RawKeyEventDataFuchsia && event.data is! RawKeyEventDataMacOs) {
      // On Fuchsia and macOS, the Fn key is not considered a modifier key.
      _keysPressed.remove(PhysicalKeyboardKey.fn);
    }
    _keysPressed.addAll(modifierKeys);
    // In rare cases, the event presses a modifier key but the key does not
    // exist in the modifier list. Enforce the pressing state.
    if (event is RawKeyDownEvent && thisKeyModifier != null
        && !_keysPressed.containsKey(event.physicalKey)) {
      // This inconsistency is found on Linux GTK for AltRight:
      // https://github.com/flutter/flutter/issues/93278
      // And also on Android and iOS:
      // https://github.com/flutter/flutter/issues/101090
      if ((event.data is RawKeyEventDataLinux && event.physicalKey == PhysicalKeyboardKey.altRight)
        || event.data is RawKeyEventDataIos
        || event.data is RawKeyEventDataAndroid) {
        final LogicalKeyboardKey? logicalKey = _allModifiersExceptFn[event.physicalKey];
        if (logicalKey != null) {
          _keysPressed[event.physicalKey] = logicalKey;
        }
      }
      // On Web, PhysicalKeyboardKey.altRight can be map to LogicalKeyboardKey.altGraph or
      // LogicalKeyboardKey.altRight:
      // https://github.com/flutter/flutter/issues/113836
      if (event.data is RawKeyEventDataWeb && event.physicalKey == PhysicalKeyboardKey.altRight) {
        _keysPressed[event.physicalKey] = event.logicalKey;
      }
    }
  }

  final Map<PhysicalKeyboardKey, LogicalKeyboardKey> _keysPressed = <PhysicalKeyboardKey, LogicalKeyboardKey>{};

  Set<LogicalKeyboardKey> get keysPressed => _keysPressed.values.toSet();

  Set<PhysicalKeyboardKey> get physicalKeysPressed => _keysPressed.keys.toSet();

  LogicalKeyboardKey? lookUpLayout(PhysicalKeyboardKey physicalKey) => _keysPressed[physicalKey];

  @visibleForTesting
  void clearKeysPressed() => _keysPressed.clear();
}

@immutable
class _ModifierSidePair {
  const _ModifierSidePair(this.modifier, this.side);

  final ModifierKey modifier;
  final KeyboardSide? side;

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is _ModifierSidePair
        && other.modifier == modifier
        && other.side == side;
  }

  @override
  int get hashCode => Object.hash(modifier, side);
}