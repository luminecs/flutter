import 'dart:async' show Completer;
import 'dart:isolate' show ReceivePort;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'binary_messenger.dart';
import 'binding.dart';

class BackgroundIsolateBinaryMessenger extends BinaryMessenger {
  BackgroundIsolateBinaryMessenger._();

  final ReceivePort _receivePort = ReceivePort();
  final Map<int, Completer<ByteData?>> _completers =
      <int, Completer<ByteData?>>{};
  int _messageCount = 0;

  static BinaryMessenger get instance {
    if (_instance == null) {
      throw StateError(
          'The BackgroundIsolateBinaryMessenger.instance value is invalid '
          'until BackgroundIsolateBinaryMessenger.ensureInitialized is '
          'executed.');
    }
    return _instance!;
  }

  static BinaryMessenger? _instance;

  static void ensureInitialized(ui.RootIsolateToken token) {
    if (_instance == null) {
      ui.PlatformDispatcher.instance.registerBackgroundIsolate(token);
      final BackgroundIsolateBinaryMessenger portBinaryMessenger =
          BackgroundIsolateBinaryMessenger._();
      _instance = portBinaryMessenger;
      portBinaryMessenger._receivePort.listen((dynamic message) {
        try {
          final List<dynamic> args = message as List<dynamic>;
          final int identifier = args[0] as int;
          final Uint8List bytes = args[1] as Uint8List;
          final ByteData byteData = ByteData.sublistView(bytes);
          portBinaryMessenger._completers
              .remove(identifier)!
              .complete(byteData);
        } catch (exception, stack) {
          FlutterError.reportError(FlutterErrorDetails(
            exception: exception,
            stack: stack,
            library: 'services library',
            context:
                ErrorDescription('during a platform message response callback'),
          ));
        }
      });
    }
  }

  @override
  Future<void> handlePlatformMessage(String channel, ByteData? data,
      ui.PlatformMessageResponseCallback? callback) {
    throw UnimplementedError('handlePlatformMessage is deprecated.');
  }

  @override
  Future<ByteData?>? send(String channel, ByteData? message) {
    final Completer<ByteData?> completer = Completer<ByteData?>();
    _messageCount += 1;
    final int messageIdentifier = _messageCount;
    _completers[messageIdentifier] = completer;
    ui.PlatformDispatcher.instance.sendPortPlatformMessage(
      channel,
      message,
      messageIdentifier,
      _receivePort.sendPort,
    );
    return completer.future;
  }

  @override
  void setMessageHandler(String channel, MessageHandler? handler) {
    throw UnsupportedError(
        'Background isolates do not support setMessageHandler(). Messages from the host platform always go to the root isolate.');
  }
}