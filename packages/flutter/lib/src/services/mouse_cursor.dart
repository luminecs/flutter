
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';

import 'system_channels.dart';

export 'package:flutter/foundation.dart' show DiagnosticLevel, DiagnosticPropertiesBuilder;
export 'package:flutter/gestures.dart' show PointerEvent;

class MouseCursorManager {
  MouseCursorManager(this.fallbackMouseCursor)
    : assert(fallbackMouseCursor != MouseCursor.defer);

  final MouseCursor fallbackMouseCursor;

  MouseCursor? debugDeviceActiveCursor(int device) {
    MouseCursor? result;
    assert(() {
      result = _lastSession[device]?.cursor;
      return true;
    }());
    return result;
  }

  final Map<int, MouseCursorSession> _lastSession = <int, MouseCursorSession>{};

  void handleDeviceCursorUpdate(
    int device,
    PointerEvent? triggeringEvent,
    Iterable<MouseCursor> cursorCandidates,
  ) {
    if (triggeringEvent is PointerRemovedEvent) {
      _lastSession.remove(device);
      return;
    }

    final MouseCursorSession? lastSession = _lastSession[device];
    final MouseCursor nextCursor = _DeferringMouseCursor.firstNonDeferred(cursorCandidates)
      ?? fallbackMouseCursor;
    assert(nextCursor is! _DeferringMouseCursor);
    if (lastSession?.cursor == nextCursor) {
      return;
    }

    final MouseCursorSession nextSession = nextCursor.createSession(device);
    _lastSession[device] = nextSession;

    lastSession?.dispose();
    nextSession.activate();
  }
}

abstract class MouseCursorSession {
  MouseCursorSession(this.cursor, this.device);

  final MouseCursor cursor;

  final int device;

  @protected
  Future<void> activate();

  @protected
  void dispose();
}

@immutable
abstract class MouseCursor with Diagnosticable {
  const MouseCursor();

  @protected
  @factory
  MouseCursorSession createSession(int device);

  String get debugDescription;

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) {
    final String debugDescription = this.debugDescription;
    if (minLevel.index >= DiagnosticLevel.info.index) {
      return debugDescription;
    }
    return super.toString(minLevel: minLevel);
  }

  static const MouseCursor defer = _DeferringMouseCursor._();

  static const MouseCursor uncontrolled = _NoopMouseCursor._();
}

class _DeferringMouseCursor extends MouseCursor {
  const _DeferringMouseCursor._();

  @override
  MouseCursorSession createSession(int device) {
    assert(false, '_DeferringMouseCursor can not create a session');
    throw UnimplementedError();
  }

  @override
  String get debugDescription => 'defer';

  static MouseCursor? firstNonDeferred(Iterable<MouseCursor> cursors) {
    for (final MouseCursor cursor in cursors) {
      if (cursor != MouseCursor.defer) {
        return cursor;
      }
    }
    return null;
  }
}

class _NoopMouseCursorSession extends MouseCursorSession {
  _NoopMouseCursorSession(_NoopMouseCursor super.cursor, super.device);

  @override
  Future<void> activate() async { /* Nothing */ }

  @override
  void dispose() { /* Nothing */ }
}

class _NoopMouseCursor extends MouseCursor {
  // Application code shouldn't directly instantiate this class, since its only
  // instance is accessible at [SystemMouseCursors.releaseControl].
  const _NoopMouseCursor._();

  @override
  @protected
  _NoopMouseCursorSession createSession(int device) => _NoopMouseCursorSession(this, device);

  @override
  String get debugDescription => 'uncontrolled';
}

class _SystemMouseCursorSession extends MouseCursorSession {
  _SystemMouseCursorSession(SystemMouseCursor super.cursor, super.device);

  @override
  SystemMouseCursor get cursor => super.cursor as SystemMouseCursor;

  @override
  Future<void> activate() {
    return SystemChannels.mouseCursor.invokeMethod<void>(
      'activateSystemCursor',
      <String, dynamic>{
        'device': device,
        'kind': cursor.kind,
      },
    );
  }

  @override
  void dispose() { /* Nothing */ }
}

class SystemMouseCursor extends MouseCursor {
  // Application code shouldn't directly instantiate system mouse cursors, since
  // the supported system cursors are enumerated in [SystemMouseCursors].
  const SystemMouseCursor._({
    required this.kind,
  });

  final String kind;

  @override
  String get debugDescription => '${objectRuntimeType(this, 'SystemMouseCursor')}($kind)';

  @override
  @protected
  MouseCursorSession createSession(int device) => _SystemMouseCursorSession(this, device);

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is SystemMouseCursor
        && other.kind == kind;
  }

  @override
  int get hashCode => kind.hashCode;

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<String>('kind', kind, level: DiagnosticLevel.debug));
  }
}

class SystemMouseCursors {
  // This class only contains static members, and should not be instantiated or
  // extended.
  SystemMouseCursors._();

  // The mapping in this class must be kept in sync with the following files in
  // the engine:
  //
  // * Android: shell/platform/android/io/flutter/plugin/mouse/MouseCursorPlugin.java
  // * Web: lib/web_ui/lib/src/engine/mouse_cursor.dart
  // * Windows: shell/platform/windows/win32_flutter_window_win32.cc
  // * Windows UWP: shell/platform/windows/win32_flutter_window_winuwp.cc
  // * Linux: shell/platform/linux/fl_mouse_cursor_plugin.cc
  // * macOS: shell/platform/darwin/macos/framework/Source/FlutterMouseCursorPlugin.mm


  static const SystemMouseCursor none = SystemMouseCursor._(kind: 'none');


  // STATUS

  static const SystemMouseCursor basic = SystemMouseCursor._(kind: 'basic');

  static const SystemMouseCursor click = SystemMouseCursor._(kind: 'click');

  static const SystemMouseCursor forbidden = SystemMouseCursor._(kind: 'forbidden');

  static const SystemMouseCursor wait = SystemMouseCursor._(kind: 'wait');

  static const SystemMouseCursor progress = SystemMouseCursor._(kind: 'progress');

  static const SystemMouseCursor contextMenu = SystemMouseCursor._(kind: 'contextMenu');

  static const SystemMouseCursor help = SystemMouseCursor._(kind: 'help');


  // SELECTION

  static const SystemMouseCursor text = SystemMouseCursor._(kind: 'text');

  static const SystemMouseCursor verticalText = SystemMouseCursor._(kind: 'verticalText');

  static const SystemMouseCursor cell = SystemMouseCursor._(kind: 'cell');

  static const SystemMouseCursor precise = SystemMouseCursor._(kind: 'precise');


  // DRAG-AND-DROP

  static const SystemMouseCursor move = SystemMouseCursor._(kind: 'move');

  static const SystemMouseCursor grab = SystemMouseCursor._(kind: 'grab');

  static const SystemMouseCursor grabbing = SystemMouseCursor._(kind: 'grabbing');

  static const SystemMouseCursor noDrop = SystemMouseCursor._(kind: 'noDrop');

  static const SystemMouseCursor alias = SystemMouseCursor._(kind: 'alias');

  static const SystemMouseCursor copy = SystemMouseCursor._(kind: 'copy');

  static const SystemMouseCursor disappearing = SystemMouseCursor._(kind: 'disappearing');


  // RESIZING AND SCROLLING

  static const SystemMouseCursor allScroll = SystemMouseCursor._(kind: 'allScroll');

  static const SystemMouseCursor resizeLeftRight = SystemMouseCursor._(kind: 'resizeLeftRight');

  static const SystemMouseCursor resizeUpDown = SystemMouseCursor._(kind: 'resizeUpDown');

  static const SystemMouseCursor resizeUpLeftDownRight = SystemMouseCursor._(kind: 'resizeUpLeftDownRight');

  static const SystemMouseCursor resizeUpRightDownLeft = SystemMouseCursor._(kind: 'resizeUpRightDownLeft');

  static const SystemMouseCursor resizeUp = SystemMouseCursor._(kind: 'resizeUp');

  static const SystemMouseCursor resizeDown = SystemMouseCursor._(kind: 'resizeDown');

  static const SystemMouseCursor resizeLeft = SystemMouseCursor._(kind: 'resizeLeft');

  static const SystemMouseCursor resizeRight = SystemMouseCursor._(kind: 'resizeRight');

  static const SystemMouseCursor resizeUpLeft = SystemMouseCursor._(kind: 'resizeUpLeft');

  static const SystemMouseCursor resizeUpRight = SystemMouseCursor._(kind: 'resizeUpRight');

  static const SystemMouseCursor resizeDownLeft = SystemMouseCursor._(kind: 'resizeDownLeft');

  static const SystemMouseCursor resizeDownRight = SystemMouseCursor._(kind: 'resizeDownRight');

  static const SystemMouseCursor resizeColumn = SystemMouseCursor._(kind: 'resizeColumn');

  static const SystemMouseCursor resizeRow = SystemMouseCursor._(kind: 'resizeRow');


  // OTHER OPERATIONS

  static const SystemMouseCursor zoomIn = SystemMouseCursor._(kind: 'zoomIn');

  static const SystemMouseCursor zoomOut = SystemMouseCursor._(kind: 'zoomOut');
}