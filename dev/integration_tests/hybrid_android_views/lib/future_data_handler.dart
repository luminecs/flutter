
import 'dart:async';

import 'package:flutter_driver/driver_extension.dart';

typedef DriverHandler = Future<String> Function();

class FutureDataHandler {
  final Map<String, Completer<DriverHandler>> _handlers = <String, Completer<DriverHandler>>{};

  Completer<DriverHandler> registerHandler(String key) {
    _handlers[key] = Completer<DriverHandler>();
    return _handlers[key]!;
  }

  Future<String> handleMessage(String? message) async {
    if (_handlers[message] == null) {
      return 'Unsupported driver message: $message.\n'
             'Supported messages are: ${_handlers.keys}.';
    }
    final DriverHandler handler = await _handlers[message]!.future;
    return handler();
  }
}

FutureDataHandler driverDataHandler = FutureDataHandler();