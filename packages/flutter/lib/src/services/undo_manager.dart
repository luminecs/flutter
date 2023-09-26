import 'package:flutter/foundation.dart';

import '../../services.dart';

enum UndoDirection {
  undo,

  redo
}

class UndoManager {
  UndoManager._() {
    _channel = SystemChannels.undoManager;
    _channel.setMethodCallHandler(_handleUndoManagerInvocation);
  }

  @visibleForTesting
  static void setChannel(MethodChannel newChannel) {
    assert(() {
      _instance._channel = newChannel
        ..setMethodCallHandler(_instance._handleUndoManagerInvocation);
      return true;
    }());
  }

  static final UndoManager _instance = UndoManager._();

  static set client(UndoManagerClient? client) {
    _instance._currentClient = client;
  }

  static UndoManagerClient? get client => _instance._currentClient;

  static void setUndoState({bool canUndo = false, bool canRedo = false}) {
    _instance._setUndoState(canUndo: canUndo, canRedo: canRedo);
  }

  late MethodChannel _channel;

  UndoManagerClient? _currentClient;

  Future<dynamic> _handleUndoManagerInvocation(MethodCall methodCall) async {
    final String method = methodCall.method;
    final List<dynamic> args = methodCall.arguments as List<dynamic>;
    if (method == 'UndoManagerClient.handleUndo') {
      assert(
          _currentClient != null, 'There must be a current UndoManagerClient.');
      _currentClient!.handlePlatformUndo(_toUndoDirection(args[0] as String));

      return;
    }

    throw MissingPluginException();
  }

  void _setUndoState({bool canUndo = false, bool canRedo = false}) {
    _channel.invokeMethod<void>('UndoManager.setUndoState',
        <String, bool>{'canUndo': canUndo, 'canRedo': canRedo});
  }

  UndoDirection _toUndoDirection(String direction) {
    switch (direction) {
      case 'undo':
        return UndoDirection.undo;
      case 'redo':
        return UndoDirection.redo;
    }
    throw FlutterError.fromParts(
        <DiagnosticsNode>[ErrorSummary('Unknown undo direction: $direction')]);
  }
}

mixin UndoManagerClient {
  void handlePlatformUndo(UndoDirection direction);

  void undo();

  void redo();

  bool get canUndo;

  bool get canRedo;
}
