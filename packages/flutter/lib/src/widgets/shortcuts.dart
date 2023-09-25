import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'actions.dart';
import 'focus_manager.dart';
import 'focus_scope.dart';
import 'framework.dart';
import 'platform_menu_bar.dart';

@immutable
class KeySet<T extends KeyboardKey> {
  KeySet(
    T key1, [
    T? key2,
    T? key3,
    T? key4,
  ])  : _keys = HashSet<T>()..add(key1) {
    int count = 1;
    if (key2 != null) {
      _keys.add(key2);
      assert(() {
        count++;
        return true;
      }());
    }
    if (key3 != null) {
      _keys.add(key3);
      assert(() {
        count++;
        return true;
      }());
    }
    if (key4 != null) {
      _keys.add(key4);
      assert(() {
        count++;
        return true;
      }());
    }
    assert(_keys.length == count, 'Two or more provided keys are identical. Each key must appear only once.');
  }

  KeySet.fromSet(Set<T> keys)
      : assert(keys.isNotEmpty),
        assert(!keys.contains(null)),
        _keys = HashSet<T>.of(keys);

  Set<T> get keys => _keys.toSet();
  final HashSet<T> _keys;

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is KeySet<T>
        && setEquals<T>(other._keys, _keys);
  }

  // Cached hash code value. Improves [hashCode] performance by 27%-900%,
  // depending on key set size and read/write ratio.
  @override
  late final int hashCode = _computeHashCode(_keys);

  // Arrays used to temporarily store hash codes for sorting.
  static final List<int> _tempHashStore3 = <int>[0, 0, 0]; // used to sort exactly 3 keys
  static final List<int> _tempHashStore4 = <int>[0, 0, 0, 0]; // used to sort exactly 4 keys
  static int _computeHashCode<T>(Set<T> keys) {
    // Compute order-independent hash and cache it.
    final int length = keys.length;
    final Iterator<T> iterator = keys.iterator;

    // There's always at least one key. Just extract it.
    iterator.moveNext();
    final int h1 = iterator.current.hashCode;

    if (length == 1) {
      // Don't do anything fancy if there's exactly one key.
      return h1;
    }

    iterator.moveNext();
    final int h2 = iterator.current.hashCode;
    if (length == 2) {
      // No need to sort if there's two keys, just compare them.
      return h1 < h2
        ? Object.hash(h1, h2)
        : Object.hash(h2, h1);
    }

    // Sort key hash codes and feed to Object.hashAll to ensure the aggregate
    // hash code does not depend on the key order.
    final List<int> sortedHashes = length == 3
      ? _tempHashStore3
      : _tempHashStore4;
    sortedHashes[0] = h1;
    sortedHashes[1] = h2;
    iterator.moveNext();
    sortedHashes[2] = iterator.current.hashCode;
    if (length == 4) {
      iterator.moveNext();
      sortedHashes[3] = iterator.current.hashCode;
    }
    sortedHashes.sort();
    return Object.hashAll(sortedHashes);
  }
}

abstract class ShortcutActivator {
  const ShortcutActivator();

  Iterable<LogicalKeyboardKey>? get triggers;

  bool accepts(RawKeyEvent event, RawKeyboard state);

  static bool isActivatedBy(ShortcutActivator activator, RawKeyEvent event) {
    return (activator.triggers?.contains(event.logicalKey) ?? true)
        && activator.accepts(event, RawKeyboard.instance);
  }

  String debugDescribeKeys();
}


class LogicalKeySet extends KeySet<LogicalKeyboardKey> with Diagnosticable
    implements ShortcutActivator {
  LogicalKeySet(
    super.key1, [
    super.key2,
    super.key3,
    super.key4,
  ]);

  LogicalKeySet.fromSet(super.keys) : super.fromSet();

  @override
  Iterable<LogicalKeyboardKey> get triggers => _triggers;
  late final Set<LogicalKeyboardKey> _triggers = keys.expand(
    (LogicalKeyboardKey key) => _unmapSynonyms[key] ?? <LogicalKeyboardKey>[key],
  ).toSet();

  @override
  bool accepts(RawKeyEvent event, RawKeyboard state) {
    if (event is! RawKeyDownEvent) {
      return false;
    }
    final Set<LogicalKeyboardKey> collapsedRequired = LogicalKeyboardKey.collapseSynonyms(keys);
    final Set<LogicalKeyboardKey> collapsedPressed = LogicalKeyboardKey.collapseSynonyms(state.keysPressed);
    final bool keysEqual = collapsedRequired.difference(collapsedPressed).isEmpty
      && collapsedRequired.length == collapsedPressed.length;
    return keysEqual;
  }

  static final Set<LogicalKeyboardKey> _modifiers = <LogicalKeyboardKey>{
    LogicalKeyboardKey.alt,
    LogicalKeyboardKey.control,
    LogicalKeyboardKey.meta,
    LogicalKeyboardKey.shift,
  };
  static final Map<LogicalKeyboardKey, List<LogicalKeyboardKey>> _unmapSynonyms = <LogicalKeyboardKey, List<LogicalKeyboardKey>>{
    LogicalKeyboardKey.control: <LogicalKeyboardKey>[LogicalKeyboardKey.controlLeft, LogicalKeyboardKey.controlRight],
    LogicalKeyboardKey.shift: <LogicalKeyboardKey>[LogicalKeyboardKey.shiftLeft, LogicalKeyboardKey.shiftRight],
    LogicalKeyboardKey.alt: <LogicalKeyboardKey>[LogicalKeyboardKey.altLeft, LogicalKeyboardKey.altRight],
    LogicalKeyboardKey.meta: <LogicalKeyboardKey>[LogicalKeyboardKey.metaLeft, LogicalKeyboardKey.metaRight],
  };

  @override
  String debugDescribeKeys() {
    final List<LogicalKeyboardKey> sortedKeys = keys.toList()
      ..sort((LogicalKeyboardKey a, LogicalKeyboardKey b) {
          // Put the modifiers first. If it has a synonym, then it's something
          // like shiftLeft, altRight, etc.
          final bool aIsModifier = a.synonyms.isNotEmpty || _modifiers.contains(a);
          final bool bIsModifier = b.synonyms.isNotEmpty || _modifiers.contains(b);
          if (aIsModifier && !bIsModifier) {
            return -1;
          } else if (bIsModifier && !aIsModifier) {
            return 1;
          }
          return a.debugName!.compareTo(b.debugName!);
        });
    return sortedKeys.map<String>((LogicalKeyboardKey key) => key.debugName.toString()).join(' + ');
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<Set<LogicalKeyboardKey>>('keys', _keys, description: debugDescribeKeys()));
  }
}

class ShortcutMapProperty extends DiagnosticsProperty<Map<ShortcutActivator, Intent>> {
  ShortcutMapProperty(
    String super.name,
    Map<ShortcutActivator, Intent> super.value, {
    super.showName,
    Object super.defaultValue,
    super.level,
    super.description,
  });

  @override
  Map<ShortcutActivator, Intent> get value => super.value!;

  @override
  String valueToString({TextTreeConfiguration? parentConfiguration}) {
    return '{${value.keys.map<String>((ShortcutActivator keySet) => '{${keySet.debugDescribeKeys()}}: ${value[keySet]}').join(', ')}}';
  }
}

class SingleActivator with Diagnosticable, MenuSerializableShortcut implements ShortcutActivator {
  const SingleActivator(
    this.trigger, {
    this.control = false,
    this.shift = false,
    this.alt = false,
    this.meta = false,
    this.includeRepeats = true,
  }) : // The enumerated check with `identical` is cumbersome but the only way
       // since const constructors can not call functions such as `==` or
       // `Set.contains`. Checking with `identical` might not work when the
       // key object is created from ID, but it covers common cases.
       assert(
         !identical(trigger, LogicalKeyboardKey.control) &&
         !identical(trigger, LogicalKeyboardKey.controlLeft) &&
         !identical(trigger, LogicalKeyboardKey.controlRight) &&
         !identical(trigger, LogicalKeyboardKey.shift) &&
         !identical(trigger, LogicalKeyboardKey.shiftLeft) &&
         !identical(trigger, LogicalKeyboardKey.shiftRight) &&
         !identical(trigger, LogicalKeyboardKey.alt) &&
         !identical(trigger, LogicalKeyboardKey.altLeft) &&
         !identical(trigger, LogicalKeyboardKey.altRight) &&
         !identical(trigger, LogicalKeyboardKey.meta) &&
         !identical(trigger, LogicalKeyboardKey.metaLeft) &&
         !identical(trigger, LogicalKeyboardKey.metaRight),
       );

  final LogicalKeyboardKey trigger;

  final bool control;

  final bool shift;

  final bool alt;

  final bool meta;

  final bool includeRepeats;

  @override
  Iterable<LogicalKeyboardKey> get triggers {
    return <LogicalKeyboardKey>[trigger];
  }

  @override
  bool accepts(RawKeyEvent event, RawKeyboard state) {
    final Set<LogicalKeyboardKey> pressed = state.keysPressed;
    return event is RawKeyDownEvent
      && (includeRepeats || !event.repeat)
      && (control == (pressed.contains(LogicalKeyboardKey.controlLeft) || pressed.contains(LogicalKeyboardKey.controlRight)))
      && (shift == (pressed.contains(LogicalKeyboardKey.shiftLeft) || pressed.contains(LogicalKeyboardKey.shiftRight)))
      && (alt == (pressed.contains(LogicalKeyboardKey.altLeft) || pressed.contains(LogicalKeyboardKey.altRight)))
      && (meta == (pressed.contains(LogicalKeyboardKey.metaLeft) || pressed.contains(LogicalKeyboardKey.metaRight)));
  }

  @override
  ShortcutSerialization serializeForMenu() {
    return ShortcutSerialization.modifier(
      trigger,
      shift: shift,
      alt: alt,
      meta: meta,
      control: control,
    );
  }

  @override
  String debugDescribeKeys() {
    String result = '';
    assert(() {
      final List<String> keys = <String>[
        if (control) 'Control',
        if (alt) 'Alt',
        if (meta) 'Meta',
        if (shift) 'Shift',
        trigger.debugName ?? trigger.toStringShort(),
      ];
      result = keys.join(' + ');
      return true;
    }());
    return result;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(MessageProperty('keys', debugDescribeKeys()));
    properties.add(FlagProperty('includeRepeats', value: includeRepeats, ifFalse: 'excluding repeats'));
  }
}

class CharacterActivator with Diagnosticable, MenuSerializableShortcut implements ShortcutActivator {
  const CharacterActivator(this.character, {
    this.alt = false,
    this.control = false,
    this.meta = false,
    this.includeRepeats = true,
  });

  final bool alt;

  final bool control;

  final bool meta;

  final bool includeRepeats;

  final String character;

  @override
  Iterable<LogicalKeyboardKey>? get triggers => null;

  @override
  bool accepts(RawKeyEvent event, RawKeyboard state) {
    final Set<LogicalKeyboardKey> pressed = state.keysPressed;
    return event is RawKeyDownEvent
      && event.character == character
      && (includeRepeats || !event.repeat)
      && (alt == (pressed.contains(LogicalKeyboardKey.altLeft) || pressed.contains(LogicalKeyboardKey.altRight)))
      && (control == (pressed.contains(LogicalKeyboardKey.controlLeft) || pressed.contains(LogicalKeyboardKey.controlRight)))
      && (meta == (pressed.contains(LogicalKeyboardKey.metaLeft) || pressed.contains(LogicalKeyboardKey.metaRight)));
  }

  @override
  String debugDescribeKeys() {
    String result = '';
    assert(() {
      final List<String> keys = <String>[
        if (alt) 'Alt',
        if (control) 'Control',
        if (meta) 'Meta',
        "'$character'",
      ];
      result = keys.join(' + ');
      return true;
    }());
    return result;
  }

  @override
  ShortcutSerialization serializeForMenu() {
    return ShortcutSerialization.character(character, alt: alt, control: control, meta: meta);
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(MessageProperty('character', debugDescribeKeys()));
    properties.add(FlagProperty('includeRepeats', value: includeRepeats, ifFalse: 'excluding repeats'));
  }
}

class _ActivatorIntentPair with Diagnosticable {
  const _ActivatorIntentPair(this.activator, this.intent);
  final ShortcutActivator activator;
  final Intent intent;

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<String>('activator', activator.debugDescribeKeys()));
    properties.add(DiagnosticsProperty<Intent>('intent', intent));
  }
}

class ShortcutManager with Diagnosticable, ChangeNotifier {
  ShortcutManager({
    Map<ShortcutActivator, Intent> shortcuts = const <ShortcutActivator, Intent>{},
    this.modal = false,
  })  : _shortcuts = shortcuts {
    if (kFlutterMemoryAllocationsEnabled) {
      ChangeNotifier.maybeDispatchObjectCreation(this);
    }
  }

  final bool modal;

  Map<ShortcutActivator, Intent> get shortcuts => _shortcuts;
  Map<ShortcutActivator, Intent> _shortcuts = <ShortcutActivator, Intent>{};
  set shortcuts(Map<ShortcutActivator, Intent> value) {
    if (!mapEquals<ShortcutActivator, Intent>(_shortcuts, value)) {
      _shortcuts = value;
      _indexedShortcutsCache = null;
      notifyListeners();
    }
  }

  static Map<LogicalKeyboardKey?, List<_ActivatorIntentPair>> _indexShortcuts(Map<ShortcutActivator, Intent> source) {
    final Map<LogicalKeyboardKey?, List<_ActivatorIntentPair>> result = <LogicalKeyboardKey?, List<_ActivatorIntentPair>>{};
    source.forEach((ShortcutActivator activator, Intent intent) {
      // This intermediate variable is necessary to comply with Dart analyzer.
      final Iterable<LogicalKeyboardKey?>? nullableTriggers = activator.triggers;
      for (final LogicalKeyboardKey? trigger in nullableTriggers ?? <LogicalKeyboardKey?>[null]) {
        result.putIfAbsent(trigger, () => <_ActivatorIntentPair>[])
          .add(_ActivatorIntentPair(activator, intent));
      }
    });
    return result;
  }

  Map<LogicalKeyboardKey?, List<_ActivatorIntentPair>> get _indexedShortcuts {
    return _indexedShortcutsCache ??= _indexShortcuts(shortcuts);
  }

  Map<LogicalKeyboardKey?, List<_ActivatorIntentPair>>? _indexedShortcutsCache;

  Intent? _find(RawKeyEvent event, RawKeyboard state) {
    final List<_ActivatorIntentPair>? candidatesByKey = _indexedShortcuts[event.logicalKey];
    final List<_ActivatorIntentPair>? candidatesByNull = _indexedShortcuts[null];
    final List<_ActivatorIntentPair> candidates = <_ActivatorIntentPair>[
      if (candidatesByKey != null) ...candidatesByKey,
      if (candidatesByNull != null) ...candidatesByNull,
    ];
    for (final _ActivatorIntentPair activatorIntent in candidates) {
      if (activatorIntent.activator.accepts(event, state)) {
        return activatorIntent.intent;
      }
    }
    return null;
  }

  @protected
  KeyEventResult handleKeypress(BuildContext context, RawKeyEvent event) {
    final Intent? matchedIntent = _find(event, RawKeyboard.instance);
    if (matchedIntent != null) {
      final BuildContext? primaryContext = primaryFocus?.context;
      if (primaryContext != null) {
        final Action<Intent>? action = Actions.maybeFind<Intent>(
          primaryContext,
          intent: matchedIntent,
        );
        if (action != null) {
          final (bool enabled, Object? invokeResult) = Actions.of(primaryContext).invokeActionIfEnabled(
            action, matchedIntent, primaryContext,
          );
          if (enabled) {
            return action.toKeyEventResult(matchedIntent, invokeResult);
          }
        }
      }
    }
    return modal ? KeyEventResult.skipRemainingHandlers : KeyEventResult.ignored;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<Map<ShortcutActivator, Intent>>('shortcuts', shortcuts));
    properties.add(FlagProperty('modal', value: modal, ifTrue: 'modal', defaultValue: false));
  }
}

class Shortcuts extends StatefulWidget {
  const Shortcuts({
    super.key,
    required Map<ShortcutActivator, Intent> shortcuts,
    required this.child,
    this.debugLabel,
  }) : _shortcuts = shortcuts,
       manager = null;

  const Shortcuts.manager({
    super.key,
    required ShortcutManager this.manager,
    required this.child,
    this.debugLabel,
  }) : _shortcuts = const <ShortcutActivator, Intent>{};

  final ShortcutManager? manager;

  Map<ShortcutActivator, Intent> get shortcuts {
    return manager == null ? _shortcuts : manager!.shortcuts;
  }
  final Map<ShortcutActivator, Intent> _shortcuts;

  final Widget child;

  final String? debugLabel;

  @override
  State<Shortcuts> createState() => _ShortcutsState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<ShortcutManager>('manager', manager, defaultValue: null));
    properties.add(ShortcutMapProperty('shortcuts', shortcuts, description: debugLabel?.isNotEmpty ?? false ? debugLabel : null));
  }
}

class _ShortcutsState extends State<Shortcuts> {
  ShortcutManager? _internalManager;
  ShortcutManager get manager => widget.manager ?? _internalManager!;

  @override
  void dispose() {
    _internalManager?.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    if (widget.manager == null) {
      _internalManager = ShortcutManager();
      _internalManager!.shortcuts = widget.shortcuts;
    }
  }

  @override
  void didUpdateWidget(Shortcuts oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.manager != oldWidget.manager) {
      if (widget.manager != null) {
        _internalManager?.dispose();
        _internalManager = null;
      } else {
        _internalManager ??= ShortcutManager();
      }
    }
    _internalManager?.shortcuts = widget.shortcuts;
  }

  KeyEventResult _handleOnKey(FocusNode node, RawKeyEvent event) {
    if (node.context == null) {
      return KeyEventResult.ignored;
    }
    return manager.handleKeypress(node.context!, event);
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      debugLabel: '$Shortcuts',
      canRequestFocus: false,
      onKey: _handleOnKey,
      child: widget.child,
    );
  }
}

class CallbackShortcuts extends StatelessWidget {
  const CallbackShortcuts({
    super.key,
    required this.bindings,
    required this.child,
  });

  final Map<ShortcutActivator, VoidCallback> bindings;

  final Widget child;

  // A helper function to make the stack trace more useful if the callback
  // throws, by providing the activator and event as arguments that will appear
  // in the stack trace.
  bool _applyKeyBinding(ShortcutActivator activator, RawKeyEvent event) {
    if (ShortcutActivator.isActivatedBy(activator, event)) {
      bindings[activator]!.call();
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKey: (FocusNode node, RawKeyEvent event) {
        KeyEventResult result = KeyEventResult.ignored;
        // Activates all key bindings that match, returns "handled" if any handle it.
        for (final ShortcutActivator activator in bindings.keys) {
          result = _applyKeyBinding(activator, event) ? KeyEventResult.handled : result;
        }
        return result;
      },
      child: child,
    );
  }
}

class ShortcutRegistryEntry {
  // Tokens can only be created by the ShortcutRegistry.
  const ShortcutRegistryEntry._(this.registry);

  final ShortcutRegistry registry;

  void replaceAll(Map<ShortcutActivator, Intent> value) {
    registry._replaceAll(this, value);
  }

  @mustCallSuper
  void dispose() {
    registry._disposeEntry(this);
  }
}

class ShortcutRegistry with ChangeNotifier {
  ShortcutRegistry() {
    if (kFlutterMemoryAllocationsEnabled) {
      ChangeNotifier.maybeDispatchObjectCreation(this);
    }
  }

  bool _notificationScheduled = false;
  bool _disposed = false;

  @override
  void dispose() {
    super.dispose();
    _disposed = true;
  }

  Map<ShortcutActivator, Intent> get shortcuts {
    assert(ChangeNotifier.debugAssertNotDisposed(this));
    return <ShortcutActivator, Intent>{
      for (final MapEntry<ShortcutRegistryEntry, Map<ShortcutActivator, Intent>> entry in _registeredShortcuts.entries)
        ...entry.value,
    };
  }

  final Map<ShortcutRegistryEntry, Map<ShortcutActivator, Intent>> _registeredShortcuts =
    <ShortcutRegistryEntry, Map<ShortcutActivator, Intent>>{};

  ShortcutRegistryEntry addAll(Map<ShortcutActivator, Intent> value) {
    assert(ChangeNotifier.debugAssertNotDisposed(this));
    assert(value.isNotEmpty, 'Cannot register an empty map of shortcuts');
    final ShortcutRegistryEntry entry = ShortcutRegistryEntry._(this);
    _registeredShortcuts[entry] = value;
    assert(_debugCheckForDuplicates());
    _notifyListenersNextFrame();
    return entry;
  }

  // Subscriber notification has to happen in the next frame because shortcuts
  // are often registered that affect things in the overlay or different parts
  // of the tree, and so can cause build ordering issues if notifications happen
  // during the build. The _notificationScheduled check makes sure we only
  // notify once per frame.
  void _notifyListenersNextFrame() {
    if (!_notificationScheduled) {
      SchedulerBinding.instance.addPostFrameCallback((Duration _) {
        _notificationScheduled = false;
        if (!_disposed) {
          notifyListeners();
        }
      });
      _notificationScheduled = true;
    }
  }

  static ShortcutRegistry of(BuildContext context) {
    final _ShortcutRegistrarScope? inherited =
      context.dependOnInheritedWidgetOfExactType<_ShortcutRegistrarScope>();
    assert(() {
      if (inherited == null) {
        throw FlutterError(
          'Unable to find a $ShortcutRegistrar widget in the context.\n'
          '$ShortcutRegistrar.of() was called with a context that does not contain a '
          '$ShortcutRegistrar widget.\n'
          'No $ShortcutRegistrar ancestor could be found starting from the context that was '
          'passed to $ShortcutRegistrar.of().\n'
          'The context used was:\n'
          '  $context',
        );
      }
      return true;
    }());
    return inherited!.registry;
  }

  static ShortcutRegistry? maybeOf(BuildContext context) {
    final _ShortcutRegistrarScope? inherited =
      context.dependOnInheritedWidgetOfExactType<_ShortcutRegistrarScope>();
    return inherited?.registry;
  }

  // Replaces all the shortcuts associated with the given entry from this
  // registry.
  void _replaceAll(ShortcutRegistryEntry entry, Map<ShortcutActivator, Intent> value) {
    assert(ChangeNotifier.debugAssertNotDisposed(this));
    assert(_debugCheckEntryIsValid(entry));
    _registeredShortcuts[entry] = value;
    assert(_debugCheckForDuplicates());
    _notifyListenersNextFrame();
  }

  // Removes all the shortcuts associated with the given entry from this
  // registry.
  void _disposeEntry(ShortcutRegistryEntry entry) {
    assert(_debugCheckEntryIsValid(entry));
    final Map<ShortcutActivator, Intent>? removedShortcut = _registeredShortcuts.remove(entry);
    if (removedShortcut != null) {
      _notifyListenersNextFrame();
    }
  }

  bool _debugCheckEntryIsValid(ShortcutRegistryEntry entry) {
    if (!_registeredShortcuts.containsKey(entry)) {
      if (entry.registry == this) {
        throw FlutterError('entry ${describeIdentity(entry)} is invalid.\n'
          'The entry has already been disposed of. Tokens are not valid after '
          'dispose is called on them, and should no longer be used.');
      } else {
        throw FlutterError('Foreign entry ${describeIdentity(entry)} used.\n'
          'This entry was not created by this registry, it was created by '
          '${describeIdentity(entry.registry)}, and should be used with that '
          'registry instead.');
      }
    }
    return true;
  }

  bool _debugCheckForDuplicates() {
    final Map<ShortcutActivator, ShortcutRegistryEntry?> previous = <ShortcutActivator, ShortcutRegistryEntry?>{};
    for (final MapEntry<ShortcutRegistryEntry, Map<ShortcutActivator, Intent>> tokenEntry in _registeredShortcuts.entries) {
      for (final ShortcutActivator shortcut in tokenEntry.value.keys) {
        if (previous.containsKey(shortcut)) {
          throw FlutterError(
            '$ShortcutRegistry: Received a duplicate registration for the '
            'shortcut $shortcut in ${describeIdentity(tokenEntry.key)} and ${previous[shortcut]}.');
        }
        previous[shortcut] = tokenEntry.key;
      }
    }
    return true;
  }
}

class ShortcutRegistrar extends StatefulWidget {
  const ShortcutRegistrar({super.key, required this.child});

  final Widget child;

  @override
  State<ShortcutRegistrar> createState() => _ShortcutRegistrarState();
}

class _ShortcutRegistrarState extends State<ShortcutRegistrar> {
  final ShortcutRegistry registry = ShortcutRegistry();
  final ShortcutManager manager = ShortcutManager();

  @override
  void initState() {
    super.initState();
    registry.addListener(_shortcutsChanged);
  }

  void _shortcutsChanged() {
    // This shouldn't need to update the widget, and avoids calling setState
    // during build phase.
    manager.shortcuts = registry.shortcuts;
  }

  @override
  void dispose() {
    registry.removeListener(_shortcutsChanged);
    registry.dispose();
    manager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _ShortcutRegistrarScope(
      registry: registry,
      child: Shortcuts.manager(
        manager: manager,
        child: widget.child,
      ),
    );
  }
}

class _ShortcutRegistrarScope extends InheritedWidget {
  const _ShortcutRegistrarScope({
    required this.registry,
    required super.child,
  });

  final ShortcutRegistry registry;

  @override
  bool updateShouldNotify(covariant _ShortcutRegistrarScope oldWidget) {
    return registry != oldWidget.registry;
  }
}