import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'actions.dart';
import 'basic.dart';
import 'binding.dart';
import 'focus_manager.dart';
import 'framework.dart';
import 'shortcuts.dart';

// "flutter/menu" Method channel methods.
const String _kMenuSetMethod = 'Menu.setMenus';
const String _kMenuSelectedCallbackMethod = 'Menu.selectedCallback';
const String _kMenuItemOpenedMethod = 'Menu.opened';
const String _kMenuItemClosedMethod = 'Menu.closed';

// Keys for channel communication map.
const String _kIdKey = 'id';
const String _kLabelKey = 'label';
const String _kEnabledKey = 'enabled';
const String _kChildrenKey = 'children';
const String _kIsDividerKey = 'isDivider';
const String _kPlatformDefaultMenuKey = 'platformProvidedMenu';
const String _kShortcutCharacter = 'shortcutCharacter';
const String _kShortcutTrigger = 'shortcutTrigger';
const String _kShortcutModifiers = 'shortcutModifiers';

class ShortcutSerialization {
  ShortcutSerialization.character(String character, {
    bool alt = false,
    bool control = false,
    bool meta = false,
  })  : assert(character.length == 1),
        _character = character,
        _trigger = null,
        _alt = alt,
        _control = control,
        _meta = meta,
        _shift = null,
        _internal = <String, Object?>{
          _kShortcutCharacter: character,
          _kShortcutModifiers: (control ? _shortcutModifierControl : 0) |
              (alt ? _shortcutModifierAlt : 0) |
              (meta ? _shortcutModifierMeta : 0),
        };

  ShortcutSerialization.modifier(
    LogicalKeyboardKey trigger, {
    bool alt = false,
    bool control = false,
    bool meta = false,
    bool shift = false,
  })  : assert(trigger != LogicalKeyboardKey.alt &&
               trigger != LogicalKeyboardKey.altLeft &&
               trigger != LogicalKeyboardKey.altRight &&
               trigger != LogicalKeyboardKey.control &&
               trigger != LogicalKeyboardKey.controlLeft &&
               trigger != LogicalKeyboardKey.controlRight &&
               trigger != LogicalKeyboardKey.meta &&
               trigger != LogicalKeyboardKey.metaLeft &&
               trigger != LogicalKeyboardKey.metaRight &&
               trigger != LogicalKeyboardKey.shift &&
               trigger != LogicalKeyboardKey.shiftLeft &&
               trigger != LogicalKeyboardKey.shiftRight,
               'Specifying a modifier key as a trigger is not allowed. '
               'Use provided boolean parameters instead.'),
        _trigger = trigger,
        _character = null,
        _alt = alt,
        _control = control,
        _meta = meta,
        _shift = shift,
        _internal = <String, Object?>{
          _kShortcutTrigger: trigger.keyId,
          _kShortcutModifiers: (alt ? _shortcutModifierAlt : 0) |
            (control ? _shortcutModifierControl : 0) |
            (meta ? _shortcutModifierMeta : 0) |
            (shift ? _shortcutModifierShift : 0),
        };

  final Map<String, Object?> _internal;

  LogicalKeyboardKey? get trigger => _trigger;
  final LogicalKeyboardKey? _trigger;

  String? get character => _character;
  final String? _character;

  bool? get alt => _alt;
  final bool? _alt;

  bool? get control => _control;
  final bool? _control;

  bool? get meta => _meta;
  final bool? _meta;

  bool? get shift => _shift;
  final bool? _shift;

  static const int _shortcutModifierAlt = 1 << 2;

  static const int _shortcutModifierControl = 1 << 3;

  static const int _shortcutModifierMeta = 1 << 0;

  static const int _shortcutModifierShift = 1 << 1;

  Map<String, Object?> toChannelRepresentation() => _internal;
}

mixin MenuSerializableShortcut implements ShortcutActivator {
  ShortcutSerialization serializeForMenu();
}

abstract class PlatformMenuDelegate {
  const PlatformMenuDelegate();

  void setMenus(List<PlatformMenuItem> topLevelMenus);

  void clearMenus();

  bool debugLockDelegate(BuildContext context);

  bool debugUnlockDelegate(BuildContext context);
}

typedef MenuItemSerializableIdGenerator = int Function(PlatformMenuItem item);

class DefaultPlatformMenuDelegate extends PlatformMenuDelegate {
  DefaultPlatformMenuDelegate({MethodChannel? channel})
      : channel = channel ?? SystemChannels.menu,
        _idMap = <int, PlatformMenuItem>{} {
    this.channel.setMethodCallHandler(_methodCallHandler);
  }

  // Map of distributed IDs to menu items.
  final Map<int, PlatformMenuItem> _idMap;
  // An ever increasing value used to dole out IDs.
  int _serial = 0;
  // The context used to "lock" this delegate to a specific instance of
  // PlatformMenuBar to make sure there is only one.
  BuildContext? _lockedContext;

  @override
  void clearMenus() => setMenus(<PlatformMenuItem>[]);

  @override
  void setMenus(List<PlatformMenuItem> topLevelMenus) {
    _idMap.clear();
    final List<Map<String, Object?>> representation = <Map<String, Object?>>[];
    if (topLevelMenus.isNotEmpty) {
      for (final PlatformMenuItem childItem in topLevelMenus) {
        representation.addAll(childItem.toChannelRepresentation(this, getId: _getId));
      }
    }
    // Currently there's only ever one window, but the channel's format allows
    // more than one window's menu hierarchy to be defined.
    final Map<String, Object?> windowMenu = <String, Object?>{
      '0': representation,
    };
    channel.invokeMethod<void>(_kMenuSetMethod, windowMenu);
  }

  final MethodChannel channel;

  int _getId(PlatformMenuItem item) {
    _serial += 1;
    _idMap[_serial] = item;
    return _serial;
  }

  @override
  bool debugLockDelegate(BuildContext context) {
    assert(() {
      // It's OK to lock if the lock isn't set, but not OK if a different
      // context is locking it.
      if (_lockedContext != null && _lockedContext != context) {
        return false;
      }
      _lockedContext = context;
      return true;
    }());
    return true;
  }

  @override
  bool debugUnlockDelegate(BuildContext context) {
    assert(() {
      // It's OK to unlock if the lock isn't set, but not OK if a different
      // context is unlocking it.
      if (_lockedContext != null && _lockedContext != context) {
        return false;
      }
      _lockedContext = null;
      return true;
    }());
    return true;
  }

  // Handles the method calls from the plugin to forward to selection and
  // open/close callbacks.
  Future<void> _methodCallHandler(MethodCall call) async {
    final int id = call.arguments as int;
    assert(
      _idMap.containsKey(id),
      'Received a menu ${call.method} for a menu item with an ID that was not recognized: $id',
    );
    if (!_idMap.containsKey(id)) {
      return;
    }
    final PlatformMenuItem item = _idMap[id]!;
    if (call.method == _kMenuSelectedCallbackMethod) {
      assert(item.onSelected == null || item.onSelectedIntent == null,
        'Only one of PlatformMenuItem.onSelected or PlatformMenuItem.onSelectedIntent may be specified');
      item.onSelected?.call();
      if (item.onSelectedIntent != null) {
        Actions.maybeInvoke(FocusManager.instance.primaryFocus!.context!, item.onSelectedIntent!);
      }
    } else if (call.method == _kMenuItemOpenedMethod) {
      item.onOpen?.call();
    } else if (call.method == _kMenuItemClosedMethod) {
      item.onClose?.call();
    }
  }
}

class PlatformMenuBar extends StatefulWidget with DiagnosticableTreeMixin {
  const PlatformMenuBar({
    super.key,
    required this.menus,
    this.child,
    @Deprecated(
      'Use the child attribute instead. '
      'This feature was deprecated after v3.1.0-0.0.pre.'
    )
    this.body,
  }) : assert(body == null || child == null,
              'The body argument is deprecated, and only one of body or child may be used.');

  final Widget? child;

  @Deprecated(
    'Use the child attribute instead. '
    'This feature was deprecated after v3.1.0-0.0.pre.'
  )
  final Widget? body;

  final List<PlatformMenuItem> menus;

  @override
  State<PlatformMenuBar> createState() => _PlatformMenuBarState();

  @override
  List<DiagnosticsNode> debugDescribeChildren() {
    return menus.map<DiagnosticsNode>((PlatformMenuItem child) => child.toDiagnosticsNode()).toList();
  }
}

class _PlatformMenuBarState extends State<PlatformMenuBar> {
  List<PlatformMenuItem> descendants = <PlatformMenuItem>[];

  @override
  void initState() {
    super.initState();
    assert(
        WidgetsBinding.instance.platformMenuDelegate.debugLockDelegate(context),
        'More than one active $PlatformMenuBar detected. Only one active '
        'platform-rendered menu bar is allowed at a time.');
    WidgetsBinding.instance.platformMenuDelegate.clearMenus();
    _updateMenu();
  }

  @override
  void dispose() {
    assert(WidgetsBinding.instance.platformMenuDelegate.debugUnlockDelegate(context),
        'tried to unlock the $DefaultPlatformMenuDelegate more than once with context $context.');
    WidgetsBinding.instance.platformMenuDelegate.clearMenus();
    super.dispose();
  }

  @override
  void didUpdateWidget(PlatformMenuBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final List<PlatformMenuItem> newDescendants = <PlatformMenuItem>[
      for (final PlatformMenuItem item in widget.menus) ...<PlatformMenuItem>[
        item,
        ...item.descendants,
      ],
    ];
    if (!listEquals(newDescendants, descendants)) {
      descendants = newDescendants;
      _updateMenu();
    }
  }

  // Updates the data structures for the menu and send them to the platform
  // plugin.
  void _updateMenu() {
    WidgetsBinding.instance.platformMenuDelegate.setMenus(widget.menus);
  }

  @override
  Widget build(BuildContext context) {
    // PlatformMenuBar is really about managing the platform menu bar, and
    // doesn't do any rendering or event handling in Flutter.
    return widget.child ?? widget.body ?? const SizedBox();
  }
}

class PlatformMenu extends PlatformMenuItem with DiagnosticableTreeMixin {
  const PlatformMenu({
    required super.label,
    this.onOpen,
    this.onClose,
    required this.menus,
  });

  @override
  final VoidCallback? onOpen;

  @override
  final VoidCallback? onClose;

  final List<PlatformMenuItem> menus;

  @override
  List<PlatformMenuItem> get descendants => getDescendants(this);

  static List<PlatformMenuItem> getDescendants(PlatformMenu item) {
    return <PlatformMenuItem>[
      for (final PlatformMenuItem child in item.menus) ...<PlatformMenuItem>[
        child,
        ...child.descendants,
      ],
    ];
  }

  @override
  Iterable<Map<String, Object?>> toChannelRepresentation(
    PlatformMenuDelegate delegate, {
    required MenuItemSerializableIdGenerator getId,
  }) {
    return <Map<String, Object?>>[serialize(this, delegate, getId)];
  }

  static Map<String, Object?> serialize(
    PlatformMenu item,
    PlatformMenuDelegate delegate,
    MenuItemSerializableIdGenerator getId,
  ) {
    final List<Map<String, Object?>> result = <Map<String, Object?>>[];
    for (final PlatformMenuItem childItem in item.menus) {
      result.addAll(childItem.toChannelRepresentation(
        delegate,
        getId: getId,
      ));
    }
    // To avoid doing type checking for groups, just filter out when there are
    // multiple sequential dividers, or when they are first or last, since
    // groups may be interleaved with non-groups, and non-groups may also add
    // dividers.
    Map<String, Object?>? previousItem;
    result.removeWhere((Map<String, Object?> item) {
      if (previousItem == null && item[_kIsDividerKey] == true) {
        // Strip any leading dividers.
        return true;
      }
      if (previousItem != null && previousItem![_kIsDividerKey] == true && item[_kIsDividerKey] == true) {
        // Strip any duplicate dividers.
        return true;
      }
      previousItem = item;
      return false;
    });
    if (result.isNotEmpty && result.last[_kIsDividerKey] == true) {
      result.removeLast();
    }
    return <String, Object?>{
      _kIdKey: getId(item),
      _kLabelKey: item.label,
      _kEnabledKey: item.menus.isNotEmpty,
      _kChildrenKey: result,
    };
  }

  @override
  List<DiagnosticsNode> debugDescribeChildren() {
    return menus.map<DiagnosticsNode>((PlatformMenuItem child) => child.toDiagnosticsNode()).toList();
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(StringProperty('label', label));
    properties.add(FlagProperty('enabled', value: menus.isNotEmpty, ifFalse: 'DISABLED'));
  }
}

class PlatformMenuItemGroup extends PlatformMenuItem {
  const PlatformMenuItemGroup({required this.members}) : super(label: '');

  @override
  final List<PlatformMenuItem> members;

  @override
  Iterable<Map<String, Object?>> toChannelRepresentation(
    PlatformMenuDelegate delegate, {
    required MenuItemSerializableIdGenerator getId,
  }) {
    assert(members.isNotEmpty, 'There must be at least one member in a PlatformMenuItemGroup');
    return serialize(this, delegate, getId: getId);
  }

  static Iterable<Map<String, Object?>> serialize(
    PlatformMenuItem group,
    PlatformMenuDelegate delegate, {
    required MenuItemSerializableIdGenerator getId,
  }) {
    final List<Map<String, Object?>> result = <Map<String, Object?>>[];
    result.add(<String, Object?>{
      _kIdKey: getId(group),
      _kIsDividerKey: true,
    });
    for (final PlatformMenuItem item in group.members) {
      result.addAll(item.toChannelRepresentation(
        delegate,
        getId: getId,
      ));
    }
    result.add(<String, Object?>{
      _kIdKey: getId(group),
      _kIsDividerKey: true,
    });
    return result;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(IterableProperty<PlatformMenuItem>('members', members));
  }
}

class PlatformMenuItem with Diagnosticable {
  const PlatformMenuItem({
    required this.label,
    this.shortcut,
    this.onSelected,
    this.onSelectedIntent,
  }) : assert(onSelected == null || onSelectedIntent == null, 'Only one of onSelected or onSelectedIntent may be specified');

  final String label;

  final MenuSerializableShortcut? shortcut;

  final VoidCallback? onSelected;

  VoidCallback? get onOpen => null;

  VoidCallback? get onClose => null;

  final Intent? onSelectedIntent;

  List<PlatformMenuItem> get descendants => const <PlatformMenuItem>[];

  List<PlatformMenuItem> get members => const <PlatformMenuItem>[];

  Iterable<Map<String, Object?>> toChannelRepresentation(
    PlatformMenuDelegate delegate, {
    required MenuItemSerializableIdGenerator getId,
  }) {
    return <Map<String, Object?>>[PlatformMenuItem.serialize(this, delegate, getId)];
  }

  static Map<String, Object?> serialize(
    PlatformMenuItem item,
    PlatformMenuDelegate delegate,
    MenuItemSerializableIdGenerator getId,
  ) {
    final MenuSerializableShortcut? shortcut = item.shortcut;
    return <String, Object?>{
      _kIdKey: getId(item),
      _kLabelKey: item.label,
      _kEnabledKey: item.onSelected != null || item.onSelectedIntent != null,
      if (shortcut != null)...shortcut.serializeForMenu().toChannelRepresentation(),
    };
  }

  @override
  String toStringShort() => '${describeIdentity(this)}($label)';

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(StringProperty('label', label));
    properties.add(DiagnosticsProperty<MenuSerializableShortcut?>('shortcut', shortcut, defaultValue: null));
    properties.add(FlagProperty('enabled', value: onSelected != null, ifFalse: 'DISABLED'));
  }
}

class PlatformProvidedMenuItem extends PlatformMenuItem {
  const PlatformProvidedMenuItem({
    required this.type,
    this.enabled = true,
  }) : super(label: ''); // The label is ignored for platform provided menus.

  final PlatformProvidedMenuItemType type;

  final bool enabled;

  static bool hasMenu(PlatformProvidedMenuItemType menu) {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        return false;
      case TargetPlatform.macOS:
        return const <PlatformProvidedMenuItemType>{
          PlatformProvidedMenuItemType.about,
          PlatformProvidedMenuItemType.quit,
          PlatformProvidedMenuItemType.servicesSubmenu,
          PlatformProvidedMenuItemType.hide,
          PlatformProvidedMenuItemType.hideOtherApplications,
          PlatformProvidedMenuItemType.showAllApplications,
          PlatformProvidedMenuItemType.startSpeaking,
          PlatformProvidedMenuItemType.stopSpeaking,
          PlatformProvidedMenuItemType.toggleFullScreen,
          PlatformProvidedMenuItemType.minimizeWindow,
          PlatformProvidedMenuItemType.zoomWindow,
          PlatformProvidedMenuItemType.arrangeWindowsInFront,
        }.contains(menu);
    }
  }

  @override
  Iterable<Map<String, Object?>> toChannelRepresentation(
    PlatformMenuDelegate delegate, {
    required MenuItemSerializableIdGenerator getId,
  }) {
    assert(() {
      if (!hasMenu(type)) {
        throw ArgumentError(
          'Platform ${defaultTargetPlatform.name} has no platform provided menu for '
          '$type. Call PlatformProvidedMenuItem.hasMenu to determine this before '
          'instantiating one.',
        );
      }
      return true;
    }());

    return <Map<String, Object?>>[
      <String, Object?>{
        _kIdKey: getId(this),
        _kEnabledKey: enabled,
        _kPlatformDefaultMenuKey: type.index,
      },
    ];
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(FlagProperty('enabled', value: enabled, ifFalse: 'DISABLED'));
  }
}

// Must be kept in sync with the plugin code's enum of the same name.
enum PlatformProvidedMenuItemType {
  about,

  quit,

  servicesSubmenu,

  hide,

  hideOtherApplications,

  showAllApplications,

  startSpeaking,

  stopSpeaking,

  toggleFullScreen,

  minimizeWindow,

  zoomWindow,

  arrangeWindowsInFront,
}