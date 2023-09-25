import 'dart:async';

import 'package:flutter/services.dart';

import 'plugin_registry.dart';

class PluginEventChannel<T> {
  const PluginEventChannel(
    this.name, [
    this.codec = const StandardMethodCodec(),
    this.binaryMessenger,
  ]);

  final String name;

  final MethodCodec codec;

  final BinaryMessenger? binaryMessenger;

  @Deprecated(
    'Replace calls to the "controller" setter with calls to the "setController" method. '
    'This feature was deprecated after v1.23.0-7.0.pre.'
  )
  set controller(StreamController<T> controller) { // ignore: avoid_setters_without_getters
    setController(controller);
  }

  void setController(StreamController<T>? controller) {
    final BinaryMessenger messenger = binaryMessenger ?? pluginBinaryMessenger;
    if (controller == null) {
      messenger.setMessageHandler(name, null);
    } else {
      // The handler object is kept alive via its handle() method
      // keeping a reference to itself. Ideally we would keep a
      // reference to it so that there was a clear ownership model,
      // but that would require making this class non-const. Having
      // this class be const is convenient since it allows references
      // to be obtained by using the constructor rather than having
      // to literally pass references around.
      final _EventChannelHandler<T> handler = _EventChannelHandler<T>(
        name,
        codec,
        controller,
        messenger,
      );
      messenger.setMessageHandler(name, handler.handle);
    }
  }
}

class _EventChannelHandler<T> {
  _EventChannelHandler(
    this.name,
    this.codec,
    this.controller,
    this.messenger,
  );

  final String name;
  final MethodCodec codec;
  final StreamController<T> controller;
  final BinaryMessenger messenger;

  StreamSubscription<T>? subscription;

  Future<ByteData>? handle(ByteData? message) {
    final MethodCall call = codec.decodeMethodCall(message);
    switch (call.method) {
      case 'listen':
        assert(call.arguments == null);
        return _listen();
      case 'cancel':
        assert(call.arguments == null);
        return _cancel();
    }
    return null;
  }

  Future<ByteData> _listen() async {
    // Cancel any existing subscription.
    await subscription?.cancel();
    subscription = controller.stream.listen((dynamic event) {
      messenger.send(name, codec.encodeSuccessEnvelope(event));
    }, onError: (dynamic error) {
      messenger.send(name, codec.encodeErrorEnvelope(code: 'error', message: '$error'));
    });
    return codec.encodeSuccessEnvelope(null);
  }

  Future<ByteData> _cancel() async {
    if (subscription == null) {
      return codec.encodeErrorEnvelope(
        code: 'error',
        message: 'No active subscription to cancel.',
      );
    }
    await subscription!.cancel();
    subscription = null;
    return codec.encodeSuccessEnvelope(null);
  }
}