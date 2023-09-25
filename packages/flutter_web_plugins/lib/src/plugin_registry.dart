import 'dart:async';
import 'dart:ui' as ui;
import 'dart:ui_web' as ui_web;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

// Examples can assume:
// import 'package:flutter_web_plugins/flutter_web_plugins.dart';
// import 'package:flutter/services.dart';
// import 'dart:ui_web' as ui_web;
// void handleFrameworkMessage(String name, ByteData? data, PlatformMessageResponseCallback? callback) { }

class Registrar extends BinaryMessenger {
  Registrar([
    @Deprecated(
      'This argument is ignored. '
      'This feature was deprecated after v1.24.0-7.0.pre.'
    )
    BinaryMessenger? binaryMessenger,
  ]);

  void registerMessageHandler() {
    ui_web.setPluginHandler(handleFrameworkMessage);
  }

  @Deprecated(
    'Use handleFrameworkMessage instead. '
    'This feature was deprecated after v1.24.0-7.0.pre.'
  )
  @override
  Future<void> handlePlatformMessage(
    String channel,
    ByteData? data,
    ui.PlatformMessageResponseCallback? callback,
  ) => handleFrameworkMessage(channel, data, callback);

  Future<void> handleFrameworkMessage(
    String channel,
    ByteData? data,
    ui.PlatformMessageResponseCallback? callback,
  ) async {
    ByteData? response;
    try {
      final MessageHandler? handler = _handlers[channel];
      if (handler != null) {
        response = await handler(data);
      }
    } catch (exception, stack) {
      FlutterError.reportError(FlutterErrorDetails(
        exception: exception,
        stack: stack,
        library: 'flutter web plugins',
        context: ErrorDescription('during a framework-to-plugin message'),
      ));
    } finally {
      if (callback != null) {
        callback(response);
      }
    }
  }

  @Deprecated(
    'This property is redundant. It returns the object on which it is called. '
    'This feature was deprecated after v1.24.0-7.0.pre.'
  )
  BinaryMessenger get messenger => this;

  final Map<String, MessageHandler> _handlers = <String, MessageHandler>{};

  @override
  Future<ByteData?> send(String channel, ByteData? message) {
    final Completer<ByteData?> completer = Completer<ByteData?>();
    ui.channelBuffers.push(channel, message, (ByteData? reply) {
      try {
        completer.complete(reply);
      } catch (exception, stack) {
        FlutterError.reportError(FlutterErrorDetails(
          exception: exception,
          stack: stack,
          library: 'flutter web plugins',
          context: ErrorDescription('during a plugin-to-framework message'),
        ));
      }
    });
    return completer.future;
  }

  @override
  void setMessageHandler(String channel, MessageHandler? handler) {
    if (handler == null) {
      _handlers.remove(channel);
    } else {
      _handlers[channel] = handler;
    }
  }
}

@Deprecated(
  'Use Registrar instead. '
  'This feature was deprecated after v1.26.0-18.0.pre.'
)
class PluginRegistry extends Registrar {
  @Deprecated(
    'Use Registrar instead. '
    'This feature was deprecated after v1.26.0-18.0.pre.'
  )
  PluginRegistry([
    @Deprecated(
      'This argument is ignored. '
      'This feature was deprecated after v1.26.0-18.0.pre.'
    )
    BinaryMessenger? binaryMessenger,
  ]) : super();

  @Deprecated(
    'This method is redundant. It returns the object on which it is called. '
    'This feature was deprecated after v1.26.0-18.0.pre.'
  )
  Registrar registrarFor(Type key) => this;
}

final Registrar webPluginRegistrar = PluginRegistry();

@Deprecated(
  'Use webPluginRegistrar instead. '
  'This feature was deprecated after v1.24.0-7.0.pre.'
)
PluginRegistry get webPluginRegistry => webPluginRegistrar as PluginRegistry;

@Deprecated(
  'Use webPluginRegistrar instead. '
  'This feature was deprecated after v1.24.0-7.0.pre.'
)
BinaryMessenger get pluginBinaryMessenger => webPluginRegistrar;