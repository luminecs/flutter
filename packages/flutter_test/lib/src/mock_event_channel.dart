import 'dart:async';

import 'package:flutter/services.dart';

abstract class MockStreamHandler {
  MockStreamHandler();

  factory MockStreamHandler.inline({
    required MockStreamHandlerOnListenCallback onListen,
    MockStreamHandlerOnCancelCallback? onCancel,
  }) => _InlineMockStreamHandler(onListen: onListen, onCancel: onCancel);

  void onListen(Object? arguments, MockStreamHandlerEventSink events);

  void onCancel(Object? arguments);
}

typedef MockStreamHandlerOnListenCallback = void Function(Object? arguments, MockStreamHandlerEventSink events);

typedef MockStreamHandlerOnCancelCallback = void Function(Object? arguments);

class _InlineMockStreamHandler extends MockStreamHandler {
  _InlineMockStreamHandler({
    required MockStreamHandlerOnListenCallback onListen,
    MockStreamHandlerOnCancelCallback? onCancel,
  })  : _onListenInline = onListen,
        _onCancelInline = onCancel;

  final MockStreamHandlerOnListenCallback _onListenInline;
  final MockStreamHandlerOnCancelCallback? _onCancelInline;

  @override
  void onListen(Object? arguments, MockStreamHandlerEventSink events) => _onListenInline(arguments, events);

  @override
  void onCancel(Object? arguments) => _onCancelInline?.call(arguments);
}

class MockStreamHandlerEventSink {
  MockStreamHandlerEventSink(EventSink<Object?> sink) : _sink = sink;

  final EventSink<Object?> _sink;

  void success(Object? event) => _sink.add(event);

  void error({
    required String code,
    String? message,
    Object? details,
  }) => _sink.addError(PlatformException(code: code, message: message, details: details));

  void endOfStream() => _sink.close();
}