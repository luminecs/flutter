
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import 'binding.dart';
import 'debug.dart';
import 'raw_keyboard.dart';
import 'system_channels.dart';

export 'dart:ui' show KeyData;

export 'package:flutter/foundation.dart' show DiagnosticPropertiesBuilder;

export 'keyboard_key.g.dart' show LogicalKeyboardKey, PhysicalKeyboardKey;
export 'raw_keyboard.dart' show RawKeyEvent, RawKeyboard;

// When using _keyboardDebug, always call it like so:
//
// assert(_keyboardDebug(() => 'Blah $foo'));
//
// It needs to be inside the assert in order to be removed in release mode, and
// it needs to use a closure to generate the string in order to avoid string
// interpolation when debugPrintKeyboardEvents is false.
//
// It will throw a StateError if you try to call it when the app is in release
// mode.
bool _keyboardDebug(
  String Function() messageFunc, [
  Iterable<Object> Function()? detailsFunc,
]) {
  if (kReleaseMode) {
    throw StateError(
      '_keyboardDebug was called in Release mode, which means they are called '
      'without being wrapped in an assert. Always call _keyboardDebug like so:\n'
      r"  assert(_keyboardDebug(() => 'Blah $foo'));"
    );
  }
  if (!debugPrintKeyboardEvents) {
    return true;
  }
  debugPrint('KEYBOARD: ${messageFunc()}');
  final Iterable<Object> details = detailsFunc?.call() ?? const <Object>[];
  if (details.isNotEmpty) {
    for (final Object detail in details) {
      debugPrint('    $detail');
    }
  }
  // Return true so that it can be used inside of an assert.
  return true;
}

enum KeyboardLockMode {
  numLock._(LogicalKeyboardKey.numLock),

  scrollLock._(LogicalKeyboardKey.scrollLock),

  capsLock._(LogicalKeyboardKey.capsLock);

  // KeyboardLockMode has a fixed pool of supported keys, enumerated as static
  // members of this class, therefore constructing is prohibited.
  const KeyboardLockMode._(this.logicalKey);

  final LogicalKeyboardKey logicalKey;

  static final Map<int, KeyboardLockMode> _knownLockModes = <int, KeyboardLockMode>{
    numLock.logicalKey.keyId: numLock,
    scrollLock.logicalKey.keyId: scrollLock,
    capsLock.logicalKey.keyId: capsLock,
  };

  static KeyboardLockMode? findLockByLogicalKey(LogicalKeyboardKey logicalKey) => _knownLockModes[logicalKey.keyId];
}

@immutable
abstract class KeyEvent with Diagnosticable {
  const KeyEvent({
    required this.physicalKey,
    required this.logicalKey,
    this.character,
    required this.timeStamp,
    this.synthesized = false,
  });

  final PhysicalKeyboardKey physicalKey;

  final LogicalKeyboardKey logicalKey;

  final String? character;

  final Duration timeStamp;

  final bool synthesized;

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<PhysicalKeyboardKey>('physicalKey', physicalKey));
    properties.add(DiagnosticsProperty<LogicalKeyboardKey>('logicalKey', logicalKey));
    properties.add(StringProperty('character', character));
    properties.add(DiagnosticsProperty<Duration>('timeStamp', timeStamp));
    properties.add(FlagProperty('synthesized', value: synthesized, ifTrue: 'synthesized'));
  }
}

class KeyDownEvent extends KeyEvent {
  const KeyDownEvent({
    required super.physicalKey,
    required super.logicalKey,
    super.character,
    required super.timeStamp,
    super.synthesized,
  });
}

class KeyUpEvent extends KeyEvent {
  const KeyUpEvent({
    required super.physicalKey,
    required super.logicalKey,
    required super.timeStamp,
    super.synthesized,
  });
}

class KeyRepeatEvent extends KeyEvent {
  const KeyRepeatEvent({
    required super.physicalKey,
    required super.logicalKey,
    super.character,
    required super.timeStamp,
  });
}

typedef KeyEventCallback = bool Function(KeyEvent event);

class HardwareKeyboard {
  static HardwareKeyboard get instance => ServicesBinding.instance.keyboard;

  final Map<PhysicalKeyboardKey, LogicalKeyboardKey> _pressedKeys = <PhysicalKeyboardKey, LogicalKeyboardKey>{};

  Set<PhysicalKeyboardKey> get physicalKeysPressed => _pressedKeys.keys.toSet();

  Set<LogicalKeyboardKey> get logicalKeysPressed => _pressedKeys.values.toSet();

  LogicalKeyboardKey? lookUpLayout(PhysicalKeyboardKey physicalKey) => _pressedKeys[physicalKey];

  final Set<KeyboardLockMode> _lockModes = <KeyboardLockMode>{};
  Set<KeyboardLockMode> get lockModesEnabled => _lockModes;

  void _assertEventIsRegular(KeyEvent event) {
    assert(() {
      const String common = 'If this occurs in real application, please report this '
        'bug to Flutter. If this occurs in unit tests, please ensure that '
        "simulated events follow Flutter's event model as documented in "
        '`HardwareKeyboard`. This was the event: ';
      if (event is KeyDownEvent) {
        assert(!_pressedKeys.containsKey(event.physicalKey),
          'A ${event.runtimeType} is dispatched, but the state shows that the physical '
          'key is already pressed. $common$event');
      } else if (event is KeyRepeatEvent || event is KeyUpEvent) {
        assert(_pressedKeys.containsKey(event.physicalKey),
          'A ${event.runtimeType} is dispatched, but the state shows that the physical '
          'key is not pressed. $common$event');
        assert(_pressedKeys[event.physicalKey] == event.logicalKey,
          'A ${event.runtimeType} is dispatched, but the state shows that the physical '
          'key is pressed on a different logical key. $common$event '
          'and the recorded logical key ${_pressedKeys[event.physicalKey]}');
      } else {
        assert(false, 'Unexpected key event class ${event.runtimeType}');
      }
      return true;
    }());
  }

  List<KeyEventCallback> _handlers = <KeyEventCallback>[];
  bool _duringDispatch = false;
  List<KeyEventCallback>? _modifiedHandlers;

  void addHandler(KeyEventCallback handler) {
    if (_duringDispatch) {
      _modifiedHandlers ??= <KeyEventCallback>[..._handlers];
      _modifiedHandlers!.add(handler);
    } else {
      _handlers.add(handler);
    }
  }

  void removeHandler(KeyEventCallback handler) {
    if (_duringDispatch) {
      _modifiedHandlers ??= <KeyEventCallback>[..._handlers];
      _modifiedHandlers!.remove(handler);
    } else {
      _handlers.remove(handler);
    }
  }

  //
  Future<void> syncKeyboardState() async {
    final Map<int, int>? keyboardState = await SystemChannels.keyboard.invokeMapMethod<int, int>(
      'getKeyboardState',
    );
    if (keyboardState != null) {
      for (final int key in keyboardState.keys) {
        final PhysicalKeyboardKey physicalKey = PhysicalKeyboardKey(key);
        final LogicalKeyboardKey logicalKey = LogicalKeyboardKey(keyboardState[key]!);
        _pressedKeys[physicalKey] = logicalKey;
      }
    }
  }

  bool _dispatchKeyEvent(KeyEvent event) {
    // This dispatching could have used the same algorithm as [ChangeNotifier],
    // but since 1) it shouldn't be necessary to support reentrantly
    // dispatching, 2) there shouldn't be many handlers (most apps should use
    // only 1, this function just uses a simpler algorithm.
    assert(!_duringDispatch, 'Nested keyboard dispatching is not supported');
    _duringDispatch = true;
    bool handled = false;
    for (final KeyEventCallback handler in _handlers) {
      try {
        final bool thisResult = handler(event);
        handled = handled || thisResult;
      } catch (exception, stack) {
        InformationCollector? collector;
        assert(() {
          collector = () => <DiagnosticsNode>[
            DiagnosticsProperty<KeyEvent>('Event', event),
          ];
          return true;
        }());
        FlutterError.reportError(FlutterErrorDetails(
          exception: exception,
          stack: stack,
          library: 'services library',
          context: ErrorDescription('while processing a key handler'),
          informationCollector: collector,
        ));
      }
    }
    _duringDispatch = false;
    if (_modifiedHandlers != null) {
      _handlers = _modifiedHandlers!;
      _modifiedHandlers = null;
    }
    return handled;
  }

  List<String> _debugPressedKeysDetails() {
    if (_pressedKeys.isEmpty) {
      return <String>['Empty'];
    }
    final List<String> details = <String>[];
    for (final PhysicalKeyboardKey physicalKey in _pressedKeys.keys) {
      details.add('$physicalKey: ${_pressedKeys[physicalKey]}');
    }
    return details;
  }

  bool handleKeyEvent(KeyEvent event) {
    assert(_keyboardDebug(() => 'Key event received: $event'));
    assert(_keyboardDebug(() => 'Pressed state before processing the event:', _debugPressedKeysDetails));
    _assertEventIsRegular(event);
    final PhysicalKeyboardKey physicalKey = event.physicalKey;
    final LogicalKeyboardKey logicalKey = event.logicalKey;
    if (event is KeyDownEvent) {
      _pressedKeys[physicalKey] = logicalKey;
      final KeyboardLockMode? lockMode = KeyboardLockMode.findLockByLogicalKey(event.logicalKey);
      if (lockMode != null) {
        if (_lockModes.contains(lockMode)) {
          _lockModes.remove(lockMode);
        } else {
          _lockModes.add(lockMode);
        }
      }
    } else if (event is KeyUpEvent) {
      _pressedKeys.remove(physicalKey);
    } else if (event is KeyRepeatEvent) {
      // Empty
    }

    assert(_keyboardDebug(() => 'Pressed state after processing the event:', _debugPressedKeysDetails));
    return _dispatchKeyEvent(event);
  }

  @visibleForTesting
  void clearState() {
    _pressedKeys.clear();
    _lockModes.clear();
    _handlers.clear();
    assert(_modifiedHandlers == null);
  }
}

enum KeyDataTransitMode {
  rawKeyData,

  keyDataThenRawKeyData,
}

@immutable
class KeyMessage {
  const KeyMessage(this.events, this.rawEvent);

  final List<KeyEvent> events;

  final RawKeyEvent? rawEvent;

  @override
  String toString() {
    return 'KeyMessage($events)';
  }
}

typedef KeyMessageHandler = bool Function(KeyMessage message);

class KeyEventManager {
  KeyEventManager(this._hardwareKeyboard, this._rawKeyboard);

  KeyMessageHandler? keyMessageHandler;

  final HardwareKeyboard _hardwareKeyboard;
  final RawKeyboard _rawKeyboard;

  // The [KeyDataTransitMode] of the current platform.
  //
  // The `_transitMode` is guaranteed to be non-null during key event callbacks.
  //
  // The `_transitMode` is null before the first event, after which it is inferred
  // and will not change throughout the lifecycle of the application.
  //
  // The `_transitMode` can be reset to null in tests using [clearState].
  KeyDataTransitMode? _transitMode;

  // The accumulated [KeyEvent]s since the last time the message is dispatched.
  //
  // If _transitMode is [KeyDataTransitMode.keyDataThenRawKeyData], then [KeyEvent]s
  // are directly received from [handleKeyData]. If _transitMode is
  // [KeyDataTransitMode.rawKeyData], then [KeyEvent]s are converted from the raw
  // key data of [handleRawKeyMessage]. Either way, the accumulated key
  // events are only dispatched along with the next [KeyMessage] when a
  // dispatchable [RawKeyEvent] is available.
  final List<KeyEvent> _keyEventsSinceLastMessage = <KeyEvent>[];

  // When a RawKeyDownEvent is skipped ([RawKeyEventData.shouldDispatchEvent]
  // is false), its physical key will be recorded here, so that its up event
  // can also be properly skipped.
  final Set<PhysicalKeyboardKey> _skippedRawKeysPressed = <PhysicalKeyboardKey>{};

  bool handleKeyData(ui.KeyData data) {
    _transitMode ??= KeyDataTransitMode.keyDataThenRawKeyData;
    switch (_transitMode!) {
      case KeyDataTransitMode.rawKeyData:
        assert(false, 'Should never encounter KeyData when transitMode is rawKeyData.');
        return false;
      case KeyDataTransitMode.keyDataThenRawKeyData:
        // Having 0 as the physical and logical ID indicates an empty key data
        // (the only occasion either field can be 0,) transmitted to ensure
        // that the transit mode is correctly inferred. These events should be
        // ignored.
        if (data.physical == 0 && data.logical == 0) {
          return false;
        }
        assert(data.physical != 0 && data.logical != 0);
        final KeyEvent event = _eventFromData(data);
        if (data.synthesized && _keyEventsSinceLastMessage.isEmpty) {
          // Dispatch the event instantly if both conditions are met:
          //
          // - The event is synthesized, therefore the result does not matter.
          // - The current queue is empty, therefore the order does not matter.
          //
          // This allows solitary synthesized `KeyEvent`s to be dispatched,
          // since they won't be followed by `RawKeyEvent`s.
          _hardwareKeyboard.handleKeyEvent(event);
          _dispatchKeyMessage(<KeyEvent>[event], null);
        } else {
          // Otherwise, postpone key event dispatching until the next raw
          // event. Normal key presses always send 0 or more `KeyEvent`s first,
          // then 1 `RawKeyEvent`.
          _keyEventsSinceLastMessage.add(event);
        }
        return false;
    }
  }

  bool _dispatchKeyMessage(List<KeyEvent> keyEvents, RawKeyEvent? rawEvent) {
    if (keyMessageHandler != null) {
      final KeyMessage message = KeyMessage(keyEvents, rawEvent);
      try {
        return keyMessageHandler!(message);
      } catch (exception, stack) {
        InformationCollector? collector;
        assert(() {
          collector = () => <DiagnosticsNode>[
            DiagnosticsProperty<KeyMessage>('KeyMessage', message),
          ];
          return true;
        }());
        FlutterError.reportError(FlutterErrorDetails(
          exception: exception,
          stack: stack,
          library: 'services library',
          context: ErrorDescription('while processing the key message handler'),
          informationCollector: collector,
        ));
      }
    }
    return false;
  }

  Future<Map<String, dynamic>> handleRawKeyMessage(dynamic message) async {
    if (_transitMode == null) {
      _transitMode = KeyDataTransitMode.rawKeyData;
      // Convert raw events using a listener so that conversion only occurs if
      // the raw event should be dispatched.
      _rawKeyboard.addListener(_convertRawEventAndStore);
    }
    final RawKeyEvent rawEvent = RawKeyEvent.fromMessage(message as Map<String, dynamic>);

    bool shouldDispatch = true;
    if (rawEvent is RawKeyDownEvent) {
      if (!rawEvent.data.shouldDispatchEvent()) {
        shouldDispatch = false;
        _skippedRawKeysPressed.add(rawEvent.physicalKey);
      } else {
        _skippedRawKeysPressed.remove(rawEvent.physicalKey);
      }
    } else if (rawEvent is RawKeyUpEvent) {
      if (_skippedRawKeysPressed.contains(rawEvent.physicalKey)) {
        _skippedRawKeysPressed.remove(rawEvent.physicalKey);
        shouldDispatch = false;
      }
    }

    bool handled = true;
    if (shouldDispatch) {
      // The following `handleRawKeyEvent` will call `_convertRawEventAndStore`
      // unless the event is not dispatched.
      handled = _rawKeyboard.handleRawKeyEvent(rawEvent);

      for (final KeyEvent event in _keyEventsSinceLastMessage) {
        handled = _hardwareKeyboard.handleKeyEvent(event) || handled;
      }
      if (_transitMode == KeyDataTransitMode.rawKeyData) {
        assert(setEquals(_rawKeyboard.physicalKeysPressed, _hardwareKeyboard.physicalKeysPressed),
          'RawKeyboard reported ${_rawKeyboard.physicalKeysPressed}, '
          'while HardwareKeyboard reported ${_hardwareKeyboard.physicalKeysPressed}');
      }

      handled = _dispatchKeyMessage(_keyEventsSinceLastMessage, rawEvent) || handled;
      _keyEventsSinceLastMessage.clear();
    }

    return <String, dynamic>{ 'handled': handled };
  }

  // Convert the raw event to key events, including synthesizing events for
  // modifiers, and store the key events in `_keyEventsSinceLastMessage`.
  //
  // This is only called when `_transitMode` is `rawKeyEvent` and if the raw
  // event should be dispatched.
  void _convertRawEventAndStore(RawKeyEvent rawEvent) {
    final PhysicalKeyboardKey physicalKey = rawEvent.physicalKey;
    final LogicalKeyboardKey logicalKey = rawEvent.logicalKey;
    final Set<PhysicalKeyboardKey> physicalKeysPressed = _hardwareKeyboard.physicalKeysPressed;
    final List<KeyEvent> eventAfterwards = <KeyEvent>[];
    final KeyEvent? mainEvent;
    final LogicalKeyboardKey? recordedLogicalMain = _hardwareKeyboard.lookUpLayout(physicalKey);
    final Duration timeStamp = ServicesBinding.instance.currentSystemFrameTimeStamp;
    final String? character = rawEvent.character == '' ? null : rawEvent.character;
    if (rawEvent is RawKeyDownEvent) {
      if (recordedLogicalMain == null) {
        mainEvent = KeyDownEvent(
          physicalKey: physicalKey,
          logicalKey: logicalKey,
          character: character,
          timeStamp: timeStamp,
        );
        physicalKeysPressed.add(physicalKey);
      } else {
        assert(physicalKeysPressed.contains(physicalKey));
        mainEvent = KeyRepeatEvent(
          physicalKey: physicalKey,
          logicalKey: recordedLogicalMain,
          character: character,
          timeStamp: timeStamp,
        );
      }
    } else {
      assert(rawEvent is RawKeyUpEvent, 'Unexpected subclass of RawKeyEvent: ${rawEvent.runtimeType}');
      if (recordedLogicalMain == null) {
        mainEvent = null;
      } else {
        mainEvent = KeyUpEvent(
          logicalKey: recordedLogicalMain,
          physicalKey: physicalKey,
          timeStamp: timeStamp,
        );
        physicalKeysPressed.remove(physicalKey);
      }
    }
    for (final PhysicalKeyboardKey key in physicalKeysPressed.difference(_rawKeyboard.physicalKeysPressed)) {
      if (key == physicalKey) {
        // Somehow, a down event is dispatched but the key is absent from
        // keysPressed. Synthesize a up event for the key, but this event must
        // be added after the main key down event.
        eventAfterwards.add(KeyUpEvent(
          physicalKey: key,
          logicalKey: logicalKey,
          timeStamp: timeStamp,
          synthesized: true,
        ));
      } else {
        _keyEventsSinceLastMessage.add(KeyUpEvent(
          physicalKey: key,
          logicalKey: _hardwareKeyboard.lookUpLayout(key)!,
          timeStamp: timeStamp,
          synthesized: true,
        ));
      }
    }
    for (final PhysicalKeyboardKey key in _rawKeyboard.physicalKeysPressed.difference(physicalKeysPressed)) {
      _keyEventsSinceLastMessage.add(KeyDownEvent(
        physicalKey: key,
        logicalKey: _rawKeyboard.lookUpLayout(key)!,
        timeStamp: timeStamp,
        synthesized: true,
      ));
    }
    if (mainEvent != null) {
      _keyEventsSinceLastMessage.add(mainEvent);
    }
    _keyEventsSinceLastMessage.addAll(eventAfterwards);
  }

  @visibleForTesting
  void clearState() {
    assert(() {
      _transitMode = null;
      _rawKeyboard.removeListener(_convertRawEventAndStore);
      _keyEventsSinceLastMessage.clear();
      return true;
    }());
  }

  static KeyEvent _eventFromData(ui.KeyData keyData) {
    final PhysicalKeyboardKey physicalKey =
        PhysicalKeyboardKey.findKeyByCode(keyData.physical) ??
            PhysicalKeyboardKey(keyData.physical);
    final LogicalKeyboardKey logicalKey =
        LogicalKeyboardKey.findKeyByKeyId(keyData.logical) ??
            LogicalKeyboardKey(keyData.logical);
    final Duration timeStamp = keyData.timeStamp;
    switch (keyData.type) {
      case ui.KeyEventType.down:
        return KeyDownEvent(
          physicalKey: physicalKey,
          logicalKey: logicalKey,
          timeStamp: timeStamp,
          character: keyData.character,
          synthesized: keyData.synthesized,
        );
      case ui.KeyEventType.up:
        assert(keyData.character == null);
        return KeyUpEvent(
          physicalKey: physicalKey,
          logicalKey: logicalKey,
          timeStamp: timeStamp,
          synthesized: keyData.synthesized,
        );
      case ui.KeyEventType.repeat:
        return KeyRepeatEvent(
          physicalKey: physicalKey,
          logicalKey: logicalKey,
          timeStamp: timeStamp,
          character: keyData.character,
        );
    }
  }
}