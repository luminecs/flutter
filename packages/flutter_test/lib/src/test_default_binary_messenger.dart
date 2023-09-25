
import 'dart:async';
import 'dart:ui' as ui;

import 'package:fake_async/fake_async.dart';
import 'package:flutter/services.dart';

import 'mock_event_channel.dart';
import 'widget_tester.dart';

typedef AllMessagesHandler = Future<ByteData?>? Function(
    String channel, MessageHandler? handler, ByteData? message);

class TestDefaultBinaryMessenger extends BinaryMessenger {
  TestDefaultBinaryMessenger(
    this.delegate, {
    Map<String, MessageHandler> outboundHandlers = const <String, MessageHandler>{},
  }) {
    _outboundHandlers.addAll(outboundHandlers);
  }

  final BinaryMessenger delegate;

  // The handlers for messages from the engine (including fake
  // messages sent by handlePlatformMessage).
  final Map<String, MessageHandler> _inboundHandlers = <String, MessageHandler>{};

  // TODO(ianh): When the superclass `handlePlatformMessage` is removed,
  // remove this @override (but leave the method).
  @override
  Future<ByteData?> handlePlatformMessage(
    String channel,
    ByteData? data,
    ui.PlatformMessageResponseCallback? callback,
  ) {
    Future<ByteData?>? result;
    if (_inboundHandlers.containsKey(channel)) {
      result = _inboundHandlers[channel]!(data);
    }
    result ??= Future<ByteData?>.value();
    if (callback != null) {
      result = result.then((ByteData? result) { callback(result); return result; });
    }
    return result;
  }

  @override
  void setMessageHandler(String channel, MessageHandler? handler) {
    if (handler == null) {
      _inboundHandlers.remove(channel);
      delegate.setMessageHandler(channel, null);
    } else {
      _inboundHandlers[channel] = handler; // used to handle fake messages sent via handlePlatformMessage
      delegate.setMessageHandler(channel, handler); // used to handle real messages from the engine
    }
  }

  final List<Future<ByteData?>> _pendingMessages = <Future<ByteData?>>[];

  int get pendingMessageCount => _pendingMessages.length;

  // Handlers that intercept and respond to outgoing messages,
  // pretending to be the platform.
  final Map<String, MessageHandler> _outboundHandlers = <String, MessageHandler>{};

  // The outbound callbacks that were actually registered, so that we
  // can implement the [checkMockMessageHandler] method.
  final Map<String, Object> _outboundHandlerIdentities = <String, Object>{};

  AllMessagesHandler? allMessagesHandler;

  @override
  Future<ByteData?>? send(String channel, ByteData? message) {
    final Future<ByteData?>? resultFuture;
    final MessageHandler? handler = _outboundHandlers[channel];
    if (allMessagesHandler != null) {
      resultFuture = allMessagesHandler!(channel, handler, message);
    } else if (handler != null) {
      resultFuture = handler(message);
    } else {
      resultFuture = delegate.send(channel, message);
    }
    if (resultFuture != null) {
      _pendingMessages.add(resultFuture);
      resultFuture
        // TODO(srawlins): Fix this static issue,
        // https://github.com/flutter/flutter/issues/105750.
        // ignore: body_might_complete_normally_catch_error
        .catchError((Object error) { /* errors are the responsibility of the caller */ })
        .whenComplete(() => _pendingMessages.remove(resultFuture));
    }
    return resultFuture;
  }

  Future<void> get platformMessagesFinished {
    return Future.wait<void>(_pendingMessages);
  }

  void setMockMessageHandler(String channel, MessageHandler? handler, [ Object? identity ]) {
    if (handler == null) {
      _outboundHandlers.remove(channel);
      _outboundHandlerIdentities.remove(channel);
    } else {
      identity ??= handler;
      _outboundHandlers[channel] = handler;
      _outboundHandlerIdentities[channel] = identity;
    }
  }

  void setMockDecodedMessageHandler<T>(BasicMessageChannel<T> channel, Future<T> Function(T? message)? handler) {
    if (handler == null) {
      setMockMessageHandler(channel.name, null);
      return;
    }
    setMockMessageHandler(channel.name, (ByteData? message) async {
      return channel.codec.encodeMessage(await handler(channel.codec.decodeMessage(message)));
    }, handler);
  }

  void setMockMethodCallHandler(MethodChannel channel, Future<Object?>? Function(MethodCall message)? handler) {
    if (handler == null) {
      setMockMessageHandler(channel.name, null);
      return;
    }
    setMockMessageHandler(channel.name, (ByteData? message) async {
      final MethodCall call = channel.codec.decodeMethodCall(message);
      try {
        return channel.codec.encodeSuccessEnvelope(await handler(call));
      } on PlatformException catch (error) {
        return channel.codec.encodeErrorEnvelope(
          code: error.code,
          message: error.message,
          details: error.details,
        );
      } on MissingPluginException {
        return null;
      } catch (error) {
        return channel.codec.encodeErrorEnvelope(code: 'error', message: '$error');
      }
    }, handler);
  }

  void setMockStreamHandler(EventChannel channel, MockStreamHandler? handler) {
    if (handler == null) {
      setMockMessageHandler(channel.name, null);
      return;
    }

    final StreamController<Object?> controller = StreamController<Object?>();
    addTearDown(controller.close);

    setMockMethodCallHandler(MethodChannel(channel.name, channel.codec), (MethodCall call) async {
      switch (call.method) {
        case 'listen':
          return handler.onListen(call.arguments, MockStreamHandlerEventSink(controller.sink));
        case 'cancel':
          return handler.onCancel(call.arguments);
        default:
          throw UnimplementedError('Method ${call.method} not implemented');
      }
    });

    final StreamSubscription<Object?> sub = controller.stream.listen(
      (Object? e) => handlePlatformMessage(
        channel.name,
        channel.codec.encodeSuccessEnvelope(e),
        null,
      ),
    );
    addTearDown(sub.cancel);
    sub.onError((Object? e) {
      if (e is! PlatformException) {
        throw ArgumentError('Stream error must be a PlatformException');
      }
      handlePlatformMessage(
        channel.name,
        channel.codec.encodeErrorEnvelope(
          code: e.code,
          message: e.message,
          details: e.details,
        ),
        null,
      );
    });
    sub.onDone(() => handlePlatformMessage(channel.name, null, null));
  }

  bool checkMockMessageHandler(String channel, Object? handler) => _outboundHandlerIdentities[channel] == handler;
}