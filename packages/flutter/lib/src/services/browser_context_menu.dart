import 'package:flutter/foundation.dart';

import 'system_channels.dart';

class BrowserContextMenu {
  BrowserContextMenu._();

  static final BrowserContextMenu _instance = BrowserContextMenu._();

  static bool get enabled => _instance._enabled;

  bool _enabled = true;

  final MethodChannel _channel = SystemChannels.contextMenu;

  static Future<void> disableContextMenu() {
    assert(kIsWeb, 'This has no effect on platforms other than web.');
    return _instance._channel
        .invokeMethod<void>(
      'disableContextMenu',
    )
        .then((_) {
      _instance._enabled = false;
    });
  }

  static Future<void> enableContextMenu() {
    assert(kIsWeb, 'This has no effect on platforms other than web.');
    return _instance._channel
        .invokeMethod<void>(
      'enableContextMenu',
    )
        .then((_) {
      _instance._enabled = true;
    });
  }
}
